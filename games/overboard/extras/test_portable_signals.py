"""Real subprocess signal tests with synthetic children, no Wine/display usage."""
import fcntl
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

import display_runner

HERE = Path(__file__).parent
CHILD = '''import os, signal, time
from pathlib import Path
root = Path(os.environ['PROBE'])
(root/'child.pid').write_text(str(os.getpid()))
def stop(*_):
    signal.signal(signal.SIGTERM, signal.SIG_IGN)
    (root/'cleaning').touch()
    while not (root/'allow-cleanup').exists(): time.sleep(.01)
    (root/'cleaned').touch()
    raise SystemExit(0)
signal.signal(signal.SIGTERM, stop)
(root/'ready').touch()
while True: time.sleep(.01)
'''
GAMESCOPE = '''import os, signal, subprocess, sys, time
from pathlib import Path
root = Path(os.environ['PROBE'])
(root/'gamescope.pid').write_text(str(os.getpid()))
signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
# Emulate a compositor exiting before its client's slow cleanup completes.
p = subprocess.Popen([sys.executable, str(root/'child.py')], start_new_session=True)
p.wait()
'''


class SignalTests(unittest.TestCase):
    def await_file(self, path, process):
        deadline = time.monotonic() + 5
        while not path.exists() and time.monotonic() < deadline:
            if process.poll() is not None:
                # Descendants may still hold the pipe open after a bad exit.
                os.set_blocking(process.stderr.fileno(), False)
                stderr = process.stderr.read() or ''
                self.fail(f'Supervisor exited ({process.returncode}) before {path.name}:\n{stderr}')
            time.sleep(.01)
        self.assertTrue(path.exists(), 'Timed out: '+path.name)

    def exercise(self, nested, real_inner=False, fault=None, normal_exit=False,
                 absent_apis=False, adoption_race=False, stop_signal=signal.SIGTERM):
        self.assertFalse(nested and real_inner)
        with tempfile.TemporaryDirectory(dir=HERE) as tmp:
            app = Path(tmp)
            (app/'game').mkdir()
            (app/'usr/bin').mkdir(parents=True)
            (app/'state/prefix').mkdir(parents=True)
            shutil.copyfile(HERE/'portable_overboard.py', app/'game/portable_overboard.py')
            # Shared module is needed by the top-level supervisor.
            shutil.copyfile(HERE/'display_runner.py', app/'game/display_runner.py')
            if fault or absent_apis:
                runner = app/'game/display_runner.py'
                injection = ''
                if absent_apis:
                    injection += "for module, name in ((os, 'pidfd_open'), (signal, 'pidfd_send_signal')):\n    if hasattr(module, name): delattr(module, name)\n"
                if fault:
                    injection += (
                        "original_pidfds = pidfd_functions\n"
                        "def pidfd_functions():\n"
                        "    functions = list(original_pidfds())\n"
                        f"    index = {0 if fault == 'open' else 1}\n"
                        "    original = functions[index]\n"
                        "    failed = False\n"
                        "    def fail_once(*args):\n"
                        "        nonlocal failed\n"
                        f"        if not failed or {fault == 'persistent-send'}:\n"
                        "            failed = True\n"
                        "            raise OSError(5, 'injected pidfd failure')\n"
                        "        return original(*args)\n"
                        "    functions[index] = fail_once\n"
                        "    return functions\n")
                runner.write_text(runner.read_text().replace(
                    "if __name__ == '__main__':", injection+"\nif __name__ == '__main__':"))
            if adoption_race:
                # Freeze traversal after the supervisor's child snapshot, then
                # make the compositor exit and wait for actual kernel adoption.
                runner = app/'game/display_runner.py'
                injection = '''
import atexit
original_pidfds = pidfd_functions
def pidfd_functions():
    open_fd, send_signal = original_pidfds()
    opened = []
    def tracking_open(pid):
        fd = open_fd(pid)
        opened.append(fd)
        return fd
    def check_closed():
        leaked = []
        for fd in opened:
            try:
                os.fstat(fd)
            except OSError:
                continue
            leaked.append(fd)
        Path(os.environ['PROBE'], 'pidfd-leaks').write_text(repr(leaked))
    atexit.register(check_closed)
    return tracking_open, send_signal
original_glob = Path.glob
adoption_injected = False
def adoption_glob(path, pattern):
    global adoption_injected
    root = Path(os.environ['PROBE'])
    compositor = int((root/'gamescope.pid').read_text())
    if not adoption_injected and str(path) == f'/proc/{compositor}/task':
        adoption_injected = True
        os.kill(compositor, signal.SIGTERM)
        client = int((root/'child.pid').read_text())
        deadline = time.monotonic() + 3
        while f'PPid:\\t{os.getpid()}\\n' not in Path(f'/proc/{client}/status').read_text():
            if time.monotonic() > deadline:
                raise RuntimeError('Timed out waiting for adoption')
            time.sleep(.005)
        (root/'adopted-during-traversal').touch()
    return original_glob(path, pattern)
Path.glob = adoption_glob
'''
                runner.write_text(runner.read_text().replace(
                    "if __name__ == '__main__':", injection+"\nif __name__ == '__main__':"))
            (app/'usr/bin/python3').symlink_to(sys.executable)
            child_source = CHILD
            if adoption_race:
                # Count rather than ignore later signals during slow cleanup.
                child_source = child_source.replace(
                    '    signal.signal(signal.SIGTERM, signal.SIG_IGN)',
                    "    with (root/'signals').open('a') as log: log.write(str(signum)+'\\n')\n"
                    "    if (root/'cleaning').exists(): return")
                child_source = child_source.replace('def stop(*_):', 'def stop(signum, *_):')
                child_source = child_source.replace('signal.signal(signal.SIGTERM, stop)',
                    'signal.signal(signal.SIGTERM, stop)\nsignal.signal(signal.SIGINT, stop)')
            (app/'child.py').write_text(child_source)
            wrapper = app/'usr/bin/gamescope'
            wrapper.write_text('#!'+sys.executable+'\n'+GAMESCOPE)
            if normal_exit:
                wrapper.write_text(wrapper.read_text().replace('p.wait()',
                    "while not (root/'exit-compositor').exists(): time.sleep(.01)"))
            wrapper.chmod(0o755)
            # Override just command selection, not the real lock or supervision.
            bootstrap = "import portable_overboard as p\np.check=lambda app: []\n"
            if not nested:
                # Supply a synthetic direct child, retaining the real parent lock.
                (app/'usr/bin/python3').unlink()
                (app/'usr/bin/python3').write_text('#!/bin/sh\nexec '+sys.executable+' "'+str(app/'child.py')+'"\n')
                (app/'usr/bin/python3').chmod(0o755)
            if real_inner:
                (app/'state/prefix/drive_c/Program Files/Psygnosis/Overboard!').mkdir(parents=True)
                (app/'portable/bin').mkdir(parents=True)
                wine = app/'portable/bin/wine'
                wine.write_text('#!'+sys.executable+'\n'+CHILD)
                wine.chmod(0o755)
                server = app/'portable/bin/wineserver'
                server.write_text('#!'+sys.executable+'\n'
                    "import os, sys, time, json\nfrom pathlib import Path\n"
                    "r=Path(os.environ['PROBE'])\n"
                    "(r/('wine-env'+sys.argv[1])).write_text(json.dumps(dict(os.environ)))\n"
                    "if '-k' in sys.argv: (r/'cleaning').touch()\n"
                    "else:\n"
                    " while not (r/'allow-cleanup').exists(): time.sleep(.01)\n"
                    " (r/'cleaned').touch()\n")
                server.chmod(0o755)
                xephyr = app/'usr/bin/Xephyr'
                xephyr.write_text('#!'+sys.executable+'\n'
                    "import os, sys, time, json\nfrom pathlib import Path\n"
                    "r=Path(os.environ['PROBE'])\n"
                    "(r/'xephyr.pid').write_text(str(os.getpid()))\n"
                    "(r/'display-env').write_text(json.dumps(dict(os.environ)))\n"
                    "os.write(int(sys.argv[sys.argv.index('-displayfd')+1]), b'42\\n')\n"
                    "while True: time.sleep(.01)\n")
                xephyr.chmod(0o755)
                # Stub Xlib observation only; execute production inner cleanup.
                inner = app/'inner.py'
                inner.write_text("import display_runner as d, sys\n"
                    "d.watch=lambda display, stop, ready, errors: (ready.set(), stop.wait())\n"
                    "try: result=d.inner()\nexcept KeyboardInterrupt: result=130\n"
                    "sys.exit(result)\n")
                (app/'usr/bin/python3').write_text('#!/bin/sh\nexec '+sys.executable+' "'+str(inner)+'"\n')
            bootstrap += "raise SystemExit(p.main())\n"
            (app/'bootstrap.py').write_text(bootstrap)
            env = dict(os.environ, PYTHONPATH=str(app/'game'), PROBE=str(app),
                       OVERBOARD_STATE=str(app/'state'), WAYLAND_DISPLAY='synthetic',
                       PATH=str(app/'usr/bin')+':'+os.environ['PATH'])
            env.pop('OVERBOARD_DISPLAY', None)
            if real_inner:
                env.update(OVERBOARD_WINE_XDG_DATA_DIRS='/original/share',
                           XDG_DATA_DIRS='/display/share:/original/share',
                           VK_DRIVER_FILES='/display/elf64-icd.json',
                           __EGL_VENDOR_LIBRARY_FILENAMES='/display/egl.json')
            process = subprocess.Popen([sys.executable, str(app/'bootstrap.py')], env=env,
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                self.await_file(app/'ready', process)
                if normal_exit:
                    (app/'exit-compositor').touch()
                else:
                    process.send_signal(stop_signal)  # parent only, never killpg
                if fault == 'persistent-send':
                    # Even a permanent failure must retain the prefix lock.
                    time.sleep(.2)
                    self.assertIsNone(process.poll())
                    with (app/'state/launch.lock').open() as lock:
                        with self.assertRaises(BlockingIOError):
                            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    os.kill(int((app/'child.pid').read_text()), signal.SIGTERM)
                self.await_file(app/'cleaning', process)
                if not normal_exit:
                    process.send_signal(stop_signal)  # repeated stop cannot skip cleanup
                self.assertIsNone(process.poll())
                second = subprocess.run([sys.executable, str(app/'bootstrap.py')], env=env,
                                        capture_output=True, text=True, timeout=3)
                self.assertEqual(second.returncode, 1)
                self.assertIn('already running', second.stderr)
                with (app/'state/launch.lock').open() as lock:
                    with self.assertRaises(BlockingIOError):
                        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                if adoption_race:
                    self.assertTrue((app/'adopted-during-traversal').exists())
                    time.sleep(.2)  # Allow multiple discovery passes during cleanup.
                    self.assertEqual((app/'signals').read_text().splitlines(), [str(stop_signal)])
                (app/'allow-cleanup').touch()
                stdout, stderr = process.communicate(timeout=5)
                self.assertTrue((app/'cleaned').exists(), stderr)
                if adoption_race:
                    self.assertEqual((app/'pidfd-leaks').read_text(), '[]')
                self.assertEqual(process.returncode, 0 if normal_exit else 128+stop_signal, stderr)
                if fault:
                    self.assertIn('injected pidfd failure', stderr)
                if real_inner:
                    import json
                    for name in ('wine-env-k', 'wine-env-w'):
                        wine_env = json.loads((app/name).read_text())
                        self.assertNotIn('VK_DRIVER_FILES', wine_env)
                        self.assertNotIn('__EGL_VENDOR_LIBRARY_FILENAMES', wine_env)
                        self.assertEqual(wine_env['XDG_DATA_DIRS'], '/original/share')
                    display_env = json.loads((app/'display-env').read_text())
                    self.assertEqual(display_env['VK_DRIVER_FILES'], '/display/elf64-icd.json')
                with (app/'state/launch.lock').open() as lock:
                    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                for pidfile in app.glob('*.pid'):
                    with self.assertRaises(ProcessLookupError):
                        os.kill(int(pidfile.read_text()), 0)
            finally:
                (app/'allow-cleanup').touch()
                for pidfile in app.glob('*.pid'):
                    try: os.kill(int(pidfile.read_text()), signal.SIGKILL)
                    except ProcessLookupError: pass
                if process.poll() is None:
                    process.kill()
                process.communicate(timeout=5)

    def test_parent_only_sigterm_keeps_direct_prefix_locked_until_cleanup(self):
        self.exercise(False)

    def test_parent_only_sigterm_runs_real_inner_cleanup_before_unlock(self):
        self.exercise(False, real_inner=True)

    def test_parent_only_sigterm_waits_for_orphaned_gamescope_client(self):
        self.exercise(True)

    def test_adoption_during_traversal_is_discovered_without_resignalling(self):
        for stop_signal in (signal.SIGTERM, signal.SIGINT):
            with self.subTest(signal=stop_signal):
                self.exercise(True, adoption_race=True, stop_signal=stop_signal)

    def test_missing_python_pidfd_apis_use_libc(self):
        self.exercise(True, absent_apis=True)

    def test_pidfd_open_error_does_not_release_live_tree(self):
        self.exercise(True, fault='open')

    def test_pidfd_send_error_does_not_release_live_tree(self):
        self.exercise(True, fault='send')

    def test_normal_compositor_exit_starts_orphan_cleanup(self):
        self.exercise(True, normal_exit=True)

    def test_persistent_pidfd_error_keeps_lock_until_tree_exits(self):
        self.exercise(True, fault='persistent-send')


class PidfdPreflightTests(unittest.TestCase):
    def test_no_libc_wrappers_fails_before_spawn(self):
        with mock.patch.object(os, 'pidfd_open', None, create=True), \
             mock.patch.object(signal, 'pidfd_send_signal', None, create=True), \
             mock.patch('ctypes.CDLL', return_value=object()), \
             mock.patch.object(subprocess, 'Popen') as spawn:
            with self.assertRaises(AttributeError):
                display_runner.supervised_call(['unused'], env={}, tree=True)
            spawn.assert_not_called()

    def test_kernel_pidfd_errors_fail_before_spawn(self):
        import errno
        for operation in ('open', 'send'):
            for code in (errno.ENOSYS, errno.EPERM):
                with self.subTest(operation=operation, errno=code):
                    error = OSError(code, os.strerror(code))
                    with mock.patch.object(os, 'pidfd_open', create=True,
                                           side_effect=error if operation == 'open' else None,
                                           return_value=123) as open_fd, \
                         mock.patch.object(signal, 'pidfd_send_signal', create=True,
                                           side_effect=error if operation == 'send' else None), \
                         mock.patch.object(os, 'close') as close_fd, \
                         mock.patch.object(subprocess, 'Popen') as spawn:
                        with self.assertRaises(OSError) as raised:
                            display_runner.supervised_call(['unused'], env={}, tree=True)
                        self.assertEqual(raised.exception.errno, code)
                        open_fd.assert_called_once_with(os.getpid())
                        if operation == 'send':
                            close_fd.assert_called_once_with(123)
                        spawn.assert_not_called()

    def test_libc_wrappers_preserve_errno(self):
        import errno
        with mock.patch.object(os, 'pidfd_open', None, create=True), \
             mock.patch.object(signal, 'pidfd_send_signal', None, create=True):
            open_fd, send_signal = display_runner.pidfd_functions()
            with self.assertRaises(OSError) as raised:
                open_fd(-1)
            self.assertEqual(raised.exception.errno, errno.EINVAL)
            with self.assertRaises(OSError) as raised:
                send_signal(-1, 0)
            self.assertEqual(raised.exception.errno, errno.EBADF)
