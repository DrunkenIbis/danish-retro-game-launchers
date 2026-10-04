#!/usr/bin/env python3
"""Windowed Gamescope + 16-bit Xephyr. No game/media modifications."""
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import threading
import time


def pidfd_functions():
    """Use Python APIs or exported libc wrappers, never guessed syscall IDs."""
    import ctypes
    libc = ctypes.CDLL(None, use_errno=True)
    open_fd = getattr(os, 'pidfd_open', None)
    send_signal = getattr(signal, 'pidfd_send_signal', None)
    if open_fd is None:
        native_open = libc.pidfd_open
        native_open.argtypes = (ctypes.c_int, ctypes.c_uint)
        native_open.restype = ctypes.c_int

        def libc_open(pid):
            result = native_open(pid, 0)
            if result < 0:
                error = ctypes.get_errno()
                raise OSError(error, os.strerror(error))
            return result
        open_fd = libc_open
    if send_signal is None:
        native_send = libc.pidfd_send_signal
        native_send.argtypes = (ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_uint)
        native_send.restype = ctypes.c_int

        def libc_send(fd, signum):
            if native_send(fd, signum, None, 0) < 0:
                error = ctypes.get_errno()
                raise OSError(error, os.strerror(error))
        send_signal = libc_send
    # Verify kernel support and permissions before any descendants exist.
    fd = open_fd(os.getpid())
    try:
        send_signal(fd, 0)
    finally:
        os.close(fd)
    return open_fd, send_signal


def supervised_call(command, *, env, tree=False):
    """Keep this launcher alive until its child (and compositor tree) is reaped.

    tree=True is for the dedicated Linux Gamescope supervisor only: adopting
    orphaned grandchildren prevents an early compositor exit from unmounting
    the AppImage while the inner runner is still cleaning up Wine.
    """
    import ctypes
    child = None
    interrupted = 0
    previous_subreaper = ctypes.c_int()
    libc = None
    open_fd = send_signal = None
    if tree:
        open_fd, send_signal = pidfd_functions()
        libc = ctypes.CDLL(None, use_errno=True)
        if libc.prctl(37, ctypes.byref(previous_subreaper), 0, 0, 0) != 0 or libc.prctl(36, 1, 0, 0, 0) != 0:
            raise OSError(ctypes.get_errno(), 'Cannot supervise Gamescope descendants')

    forwarding_error_reported = False
    # Retain stable identities across discovery passes, not just numeric PIDs.
    retained = {}
    signalled = set()

    def close_handle(handle):
        try:
            os.close(handle)
        except OSError as exc:
            report_forward_error(exc)

    def report_forward_error(exc):
        nonlocal forwarding_error_reported
        if not forwarding_error_reported:
            forwarding_error_reported = True
            try:
                print(f'Overboard signal forwarding failed; retaining supervision and retrying: {exc}',
                      file=sys.stderr, flush=True)
            except Exception:
                pass  # A closed log pipe must not abandon live descendants.

    def forward(signum):
        failed = False
        if child is not None:
            try:
                if tree:
                    assert open_fd is not None and send_signal is not None
                    # Gamescope clients can create their own sessions. A
                    # process-group signal alone misses those children.
                    pending = [os.getpid()]
                    handles = []
                    seen = set(pending)
                    while pending:
                        pid = pending.pop()
                        for entry in Path(f'/proc/{pid}/task').glob('*/children'):
                            try:
                                children = entry.read_text().split()
                            except FileNotFoundError:
                                continue
                            for item in children:
                                descendant = int(item)
                                if descendant in seen:
                                    continue
                                seen.add(descendant)
                                pending.append(descendant)
                                try:
                                    handle = retained.get(descendant)
                                    if handle is not None:
                                        poller = select.poll()
                                        poller.register(handle, select.POLLIN)
                                        if poller.poll(0):
                                            # The old identity exited; this PID
                                            # may now name a different client.
                                            del retained[descendant]
                                            signalled.discard(handle)
                                            close_handle(handle)
                                            handle = None
                                    if handle is None:
                                        handle = open_fd(descendant)
                                        retained[descendant] = handle
                                    handles.append(handle)
                                except ProcessLookupError:
                                    pass
                                except Exception as exc:
                                    failed = True
                                    report_forward_error(exc)
                    # Signal children before parents, once per live identity.
                    # Failed sends remain eligible for the next discovery pass.
                    for handle in reversed(handles):
                        if handle in signalled:
                            continue
                        try:
                            send_signal(handle, signum)
                            signalled.add(handle)
                        except ProcessLookupError:
                            pass
                        except Exception as exc:
                            failed = True
                            report_forward_error(exc)
                else:
                    child.send_signal(signum)
            except ProcessLookupError:
                pass
            except Exception as exc:
                failed = True
                report_forward_error(exc)
        return not failed

    def stop(signum, frame):
        nonlocal interrupted
        if not interrupted:
            interrupted = signum
        # Do no I/O in the handler: failures must never unwind child cleanup.

    old = {sig: signal.signal(sig, stop) for sig in (signal.SIGTERM, signal.SIGINT)}
    try:
        child = subprocess.Popen(command, env=env, start_new_session=tree)
        forwarded = False
        while True:
            result = child.poll()
            if (tree or not forwarded) and (interrupted or (tree and result is not None)):
                # Adoption can occur between /proc reads. Keep discovering until
                # reaped, without re-signalling clients already doing cleanup.
                forwarded = forward(interrupted or signal.SIGTERM)
            if result is not None:
                if not tree:
                    break
                # No timeout: keep the lock/mount until all adopted children
                # exit. Poll so transient forwarding failures can be retried.
                try:
                    os.waitpid(-1, os.WNOHANG)
                except ChildProcessError:
                    break
            time.sleep(.05)
        return 128+interrupted if interrupted else result
    finally:
        for handle in retained.values():
            close_handle(handle)
        for sig, handler in old.items():
            signal.signal(sig, handler)
        if libc is not None:
            libc.prctl(36, previous_subreaper.value, 0, 0, 0)


def gamescope_command(python, script):
    backend = os.environ.get('OVERBOARD_GAMESCOPE_BACKEND', 'sdl')
    if backend not in ('sdl', 'wayland'):
        raise ValueError('Unsupported Overboard display backend: ' + backend)
    return ['gamescope', '--backend', backend, '-W', '1024', '-H', '768',
            '-w', '1024', '-h', '768', '-S', 'fit', '-F', 'linear',
            '--', python, script, '--inner']


def mode_index(sizes, wanted):
    return next((i for i, size in enumerate(sizes) if size == wanted), None)


def watch(display_name, stop, ready, errors,
          desktop_name='OverboardFixed - Wine desktop'):
    sys.path.insert(0, str(Path(__file__).parent/'vendor'))
    from Xlib.display import Display
    from Xlib.ext import randr  # registers RandR methods
    from Xlib.error import ConnectionClosedError, BadWindow
    d = None
    try:
        d = Display(display_name)
        root = d.screen().root
        ready.set()
        while not stop.wait(0.1):
            for window in root.query_tree().children:
                try:
                    if window.get_wm_name() != desktop_name:
                        continue
                    g = window.get_geometry()
                    info = root.xrandr_get_screen_info()
                    sizes = [(s.width_in_pixels, s.height_in_pixels) for s in info.sizes]
                    idx = mode_index(sizes, (g.width, g.height))
                    if idx is not None and idx != info.size_id:
                        reply = root.xrandr_set_screen_config(idx, 1, info.config_timestamp)
                        d.sync()
                        print(f'Inner {g.width}x{g.height}, status {reply.status}', flush=True)
                except BadWindow:
                    continue
    except ConnectionClosedError:
        print('Display closed; size helper stopped normally.', flush=True)
    except Exception as exc:
        errors.append(str(exc))
    finally:
        if d:
            try:
                d.close()
            except Exception:
                pass


def runtime_paths(app):
    return (Path(os.environ.get('OVERBOARD_WINE', str(app/'wine/bin/wine'))),
            Path(os.environ.get('OVERBOARD_XEPHYR', str(app/'usr/bin/Xephyr'))))


def wine_environment():
    env = os.environ.copy()
    # Wine uses X11/32-bit GLX. Do not pass Gamescope's ELF64 ICDs or EGL
    # discovery paths across this boundary; Xephyr/Gamescope retain their env.
    env.pop('WAYLAND_DISPLAY', None)
    original_data = env.pop('OVERBOARD_WINE_XDG_DATA_DIRS', None)
    if original_data is not None:
        for name in ('VK_DRIVER_FILES', 'VK_ICD_FILENAMES', 'VK_ADD_DRIVER_FILES',
                     '__EGL_VENDOR_LIBRARY_FILENAMES', '__EGL_VENDOR_LIBRARY_DIRS',
                     'LIBGL_DRIVERS_PATH', 'LIBDECOR_PLUGIN_DIR', 'GAMESCOPE_SCRIPT_PATH'):
            env.pop(name, None)
        env['XDG_DATA_DIRS'] = original_data or '/usr/local/share:/usr/share'
        overrides = env.get('WINEDLLOVERRIDES', '')
        env['WINEDLLOVERRIDES'] = (overrides+';' if overrides else '')+'winevulkan='
    return env


def xephyr_environment():
    env = os.environ.copy()
    # Opt-in diagnostic: copy pixels rather than sharing a mutable image buffer.
    # Keep this scoped to Xephyr, and preserve the baseline for A/B comparison.
    if env.get('OVERBOARD_COPY_FRAMES') == '1':
        env['XEPHYR_NO_SHM'] = '1'
    return env


def xephyr_command(executable, display_fd):
    args = [str(executable), '-displayfd', str(display_fd),
            '-screen', '1024x768x16', '-nolisten', 'tcp', '-noreset',
            '-title', 'Overboard windowed']
    if os.environ.get('OVERBOARD_GLAMOR') == '1':
        args.append('-glamor')
    return args


def inner():
    app = Path(__file__).resolve().parent.parent
    prefix = Path(os.environ['WINEPREFIX'])
    wine, xephyr = runtime_paths(app)
    server = wine.parent/'wineserver'
    rfd, wfd = os.pipe()
    stop = threading.Event()
    ready = threading.Event()
    errors = []
    watcher = None
    xserver = None
    env = wine_environment()
    def interrupted(signum, frame):
        raise KeyboardInterrupt()
    signal.signal(signal.SIGTERM, interrupted)
    try:
        xserver = subprocess.Popen(xephyr_command(xephyr, wfd),
                                  pass_fds=(wfd,), env=xephyr_environment())
        os.close(wfd)
        wfd = -1
        if not select.select([rfd], [], [], float(os.environ.get('OVERBOARD_XSERVER_TIMEOUT', '120')))[0]:
            raise RuntimeError('Xephyr startup timeout')
        number = os.read(rfd, 64).decode().strip()
        if not number.isdigit():
            raise RuntimeError('Xephyr did not allocate a display')
        display = ':' + number
        env.update(DISPLAY=display, WINEDEBUG=os.environ.get('OVERBOARD_WINEDEBUG', '-all'))
        watcher = threading.Thread(target=watch, args=(display, stop, ready, errors), daemon=True)
        watcher.start()
        if not ready.wait(float(os.environ.get('OVERBOARD_XSERVER_TIMEOUT', '120'))) or errors:
            raise RuntimeError('Size helper not ready: ' + '; '.join(errors))
        print('Size helper READY before Wine; 16-bit windowed mode.', flush=True)
        result = subprocess.run([str(wine), 'explorer', '/desktop=OverboardFixed,1024x768',
            r'C:\Program Files\Psygnosis\Overboard!\Ob.exe'], env=env,
            cwd=prefix/'drive_c/Program Files/Psygnosis/Overboard!')
        subprocess.run([str(server), '-w'], env=env)
        if errors:
            raise RuntimeError('Size helper failed: ' + '; '.join(errors))
        return result.returncode
    finally:
        # Repeated parent/group signals must not interrupt wineserver cleanup.
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        signal.signal(signal.SIGINT, signal.SIG_IGN)
        stop.set()
        try:
            subprocess.run([str(server), '-k'], env=env, capture_output=True)
            subprocess.run([str(server), '-w'], env=env, capture_output=True)
        finally:
            try:
                if watcher:
                    watcher.join(timeout=2)
            finally:
                try:
                    if xserver:
                        xserver.terminate()
                        try:
                            xserver.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            xserver.kill()
                            xserver.wait()
                finally:
                    try:
                        os.close(rfd)
                    finally:
                        if wfd >= 0:
                            os.close(wfd)


if __name__ == '__main__':
    try:
        if '--follow' in sys.argv:
            import argparse
            parser = argparse.ArgumentParser(description='Resize a nested X11 display to its Wine desktop.')
            parser.add_argument('--follow', required=True, metavar='DISPLAY')
            parser.add_argument('--desktop-name', default='OverboardFixed - Wine desktop')
            args = parser.parse_args()
            stop = threading.Event()
            signal.signal(signal.SIGTERM, lambda *_: stop.set())
            errors = []
            watch(args.follow, stop, threading.Event(), errors, args.desktop_name)
            if errors:
                raise RuntimeError('; '.join(errors))
            sys.exit(0)
        if '--inner' in sys.argv:
            sys.exit(inner())
        env = os.environ.copy()
        env['SDL_VIDEODRIVER'] = 'x11'
        sys.exit(supervised_call(gamescope_command(os.environ.get('OVERBOARD_PYTHON', sys.executable), str(Path(__file__).resolve())), env=env, tree=True))
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as exc:
        print('Overboard display: ' + str(exc), file=sys.stderr)
        sys.exit(1)
