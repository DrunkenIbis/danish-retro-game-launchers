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


def gamescope_command(python, script):
    return ['gamescope', '--backend', 'sdl', '-W', '1024', '-H', '768',
            '-w', '1024', '-h', '768', '-S', 'fit', '-F', 'linear',
            '--', python, script, '--inner']


def mode_index(sizes, wanted):
    return next((i for i, size in enumerate(sizes) if size == wanted), None)


def watch(display_name, stop, ready, errors):
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
                    if window.get_wm_name() != 'OverboardFixed - Wine desktop':
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


def inner():
    app = Path(__file__).resolve().parent.parent
    prefix = Path(os.environ['WINEPREFIX'])
    wine = app/'wine/bin/wine'
    server = wine.parent/'wineserver'
    rfd, wfd = os.pipe()
    stop = threading.Event()
    ready = threading.Event()
    errors = []
    watcher = None
    xserver = None
    def interrupted(signum, frame):
        raise KeyboardInterrupt()
    signal.signal(signal.SIGTERM, interrupted)
    try:
        xserver = subprocess.Popen([str(app/'usr/bin/Xephyr'), '-displayfd', str(wfd),
            '-screen', '1024x768x16', '-resizeable', '-nolisten', 'tcp', '-noreset',
            '-title', 'Overboard windowed'], pass_fds=(wfd,))
        os.close(wfd)
        wfd = -1
        if not select.select([rfd], [], [], 15)[0]:
            raise RuntimeError('Xephyr startup timeout')
        number = os.read(rfd, 64).decode().strip()
        if not number.isdigit():
            raise RuntimeError('Xephyr did not allocate a display')
        display = ':' + number
        env = os.environ.copy()
        env.update(DISPLAY=display, WINEDEBUG='-all')
        # X11 Wine backend must target the nested 16-bit server, not outer Wayland.
        env.pop('WAYLAND_DISPLAY', None)
        watcher = threading.Thread(target=watch, args=(display, stop, ready, errors), daemon=True)
        watcher.start()
        if not ready.wait(10) or errors:
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
        stop.set()
        try:
            subprocess.run([str(server), '-k'], capture_output=True)
            subprocess.run([str(server), '-w'], timeout=20, capture_output=True)
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
        if '--inner' in sys.argv:
            sys.exit(inner())
        env = os.environ.copy()
        env['SDL_VIDEODRIVER'] = 'x11'
        sys.exit(subprocess.call(gamescope_command(sys.executable, str(Path(__file__).resolve())), env=env))
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as exc:
        print('Overboard display: ' + str(exc), file=sys.stderr)
        sys.exit(1)
