import os
from pathlib import Path
import subprocess
import tempfile
import shutil
import unittest

HERE = Path(__file__).resolve().parent
ID = 'magnus-myggen-mysteriet-om-det-talende-solur'
GAME = 'Program Files/IVANOFF Interactive/Mysteriet om det talende solur'

class BundleTest(unittest.TestCase):
    def make_bundle(self, tmp, wine_script, server_script):
        app = Path(tmp) / 'app'
        seed = app / 'game/prefix'
        (seed / 'drive_c' / GAME).mkdir(parents=True)
        (seed / 'dosdevices').mkdir()
        (seed / 'system.reg').write_text('test fixture')
        (app / 'game/cdrom').mkdir()
        for relative, script in [
            ('usr/lib/wine-wow64/wine/i386-unix/wine', wine_script),
            ('usr/bin/wineserver', server_script),
        ]:
            executable = app / relative
            executable.parent.mkdir(parents=True, exist_ok=True)
            executable.write_text('#!/bin/sh\n' + script)
            executable.chmod(0o755)
        shutil.copy2(HERE / 'AppRun', app / 'AppRun')
        env = dict(os.environ, XDG_DATA_HOME=str(Path(tmp) / 'state'),
                   CALL_LOG=str(Path(tmp) / 'calls'))
        return app, env

    def test_nonzero_wine_still_waits_and_preserves_status(self):
        with tempfile.TemporaryDirectory(prefix='solur bundle ') as tmp:
            app, env = self.make_bundle(
                tmp, 'exit 23\n',
                'printf "%s|%s\\n" "$WINEPREFIX" "$*" >> "$CALL_LOG"\nexit 7\n')
            result = subprocess.run(['bash', str(app / 'AppRun')], env=env,
                                    capture_output=True, timeout=5)
            self.assertEqual(result.returncode, 23, result.stderr)
            self.assertTrue(Path(env['CALL_LOG']).exists(), 'bundled wineserver never waited')
            prefix = Path(env['XDG_DATA_HOME']) / ID / 'prefix'
            self.assertEqual(Path(env['CALL_LOG']).read_text(), f'{prefix}|-w\n')

    def test_signals_stop_scoped_server_and_wait(self):
        import signal
        import time

        for sig in (signal.SIGINT, signal.SIGTERM):
            for phase in ('wine', 'server'):
                with self.subTest(signal=sig, phase=phase), tempfile.TemporaryDirectory() as tmp:
                    blocker = ('exec python3 -c \'import os, signal; from pathlib import Path; '
                               'Path(os.environ["CALL_LOG"] + ".pid").write_text(str(os.getpid())); '
                               'signal.pause()\'\n')
                    server = ('printf "%s|%s\\n" "$WINEPREFIX" "$*" >> "$CALL_LOG"\n'
                              'if [ "$1" = -k ]; then\n'
                              '  touch "$CALL_LOG.stopped"\n'
                              '  kill -TERM "$(cat "$CALL_LOG.pid")"\n'
                              '  exit 9\nfi\n')
                    if phase == 'server':
                        server += 'if [ ! -f "$CALL_LOG.stopped" ]; then\n' + blocker + 'fi\n'
                    app, env = self.make_bundle(tmp, blocker if phase == 'wine' else 'exit 0\n', server)
                    proc = subprocess.Popen(['bash', str(app / 'AppRun')], env=env,
                                            stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                    pidfile = Path(env['CALL_LOG'] + '.pid')
                    try:
                        deadline = time.monotonic() + 5
                        while not pidfile.exists() and time.monotonic() < deadline:
                            time.sleep(0.01)
                        self.assertTrue(pidfile.exists(), 'fixture did not start')
                        proc.send_signal(sig)
                        try:
                            _, stderr = proc.communicate(timeout=2)
                        except subprocess.TimeoutExpired:
                            self.fail('AppRun did not clean up promptly on signal')
                        self.assertEqual(proc.returncode, 128 + sig, stderr)
                        prefix = Path(env['XDG_DATA_HOME']) / ID / 'prefix'
                        calls = Path(env['CALL_LOG']).read_text().splitlines()
                        expected = [f'{prefix}|-k', f'{prefix}|-w']
                        if phase == 'server':
                            expected.insert(0, f'{prefix}|-w')
                        self.assertEqual(calls, expected)
                    finally:
                        if pidfile.exists():
                            try:
                                os.kill(int(pidfile.read_text()), signal.SIGTERM)
                            except ProcessLookupError:
                                pass
                        if proc.poll() is None:
                            proc.kill()
                        proc.communicate(timeout=5)

    def test_seed_and_preserve(self):
        self.assertTrue((HERE / 'AppRun').exists(), 'AppRun missing')
        with tempfile.TemporaryDirectory(prefix='solur bundle ') as tmp:
            app = Path(tmp) / 'app'
            seed = app / 'game/prefix'
            (seed / 'drive_c' / GAME / 'sav').mkdir(parents=True)
            (seed / 'dosdevices').mkdir()
            (seed / 'system.reg').write_text('test fixture')
            (seed / 'drive_c' / GAME / 'mm6.exe').write_text('test fixture')
            (app / 'game/cdrom').mkdir()
            wine = app / 'usr/lib/wine-wow64/wine/i386-unix/wine'
            wine.parent.mkdir(parents=True)
            wine.write_text('#!/bin/sh\ntest -f mm6.exe && test -f "$WINEPREFIX/system.reg"\n')
            wine.chmod(0o755)
            server = app / 'usr/bin/wineserver'
            server.parent.mkdir(parents=True)
            server.write_text('#!/bin/sh\nexit 0\n')
            server.chmod(0o755)
            shutil.copy2(HERE / 'AppRun', app / 'AppRun')
            env = dict(os.environ, XDG_DATA_HOME=str(Path(tmp) / 'state'))
            save = Path(tmp) / 'state' / ID / 'prefix/drive_c' / GAME / 'sav/test.sav'
            for i in range(2):
                r = subprocess.run(['bash', str(app / 'AppRun')], env=env, capture_output=True)
                self.assertEqual(r.returncode, 0, r.stderr)
                if i == 0:
                    save.write_text('progress')
                self.assertEqual(save.read_text(), 'progress')

class ToolPinTest(unittest.TestCase):
    def run_pin_check(self, tmp, executable=True):
        tool = Path(tmp) / 'local/cache/gys-paa-regneslottet/appimagetool-x86_64.AppImage'
        tool.parent.mkdir(parents=True)
        tool.write_text('not the pinned appimagetool')
        tool.chmod(0o755 if executable else 0o644)
        source = (HERE / 'build_appimage.sh').read_text()
        # Execute only the pin gate, never the builder or shared helper.
        gate = source.split('APPIMAGETOOL_BIN=', 1)[1].split('DOWNLOAD_APPIMAGETOOL=', 1)[0]
        return subprocess.run(['bash', '-euc', 'APPIMAGETOOL_BIN=' + gate],
                              env=dict(os.environ, REPO=tmp, PYTHONOPTIMIZE='1'),
                              capture_output=True, text=True, timeout=5)

    def test_nonexecutable_tool_rejected_before_helper_can_fallback(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_pin_check(tmp, executable=False)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Pinned appimagetool is not executable', result.stderr)

    def test_checksum_rejected_with_python_optimization(self):
        with tempfile.TemporaryDirectory() as tmp:
            result = self.run_pin_check(tmp)
            self.assertNotEqual(result.returncode, 0, 'optimized Python bypassed checksum')
            self.assertIn('appimagetool checksum mismatch', result.stderr)


if __name__ == '__main__':
    unittest.main()
