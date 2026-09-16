"""Contract tests; fake Wine does not establish gameplay compatibility."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('launch.sh')

class LauncherTests(unittest.TestCase):
    def run_case(self, missing=None, fail=False):
        with tempfile.TemporaryDirectory(prefix='midnight test ') as td:
            root = Path(td)
            runtime = root / 'runtime'
            game = runtime / 'prefix-ge-xp/drive_c/Program Files/Magnus & Myggen - Midnatsmysteriet'
            game.mkdir(parents=True)
            (game / 'mm13main.exe').touch()
            (runtime / 'cdrom').mkdir()
            runner = root / 'runner'
            (runner / 'bin').mkdir(parents=True)
            log = root / 'calls'
            for name in ['wine', 'wineserver']:
                f = runner / 'bin' / name
                f.write_text('#!/bin/sh\nprintf "%s\\n" "$0" "$@" >> "$CALLS"\n' + ('exit 7\n' if name == 'wine' and fail else 'exit 0\n'))
                f.chmod(0o755)
            if missing == 'exe':
                (game / 'mm13main.exe').unlink()
            if missing == 'cd':
                (runtime / 'cdrom').rmdir()
            env = {k:v for k,v in os.environ.items() if k not in ['WINEPREFIX','WINEARCH','WINEDLLOVERRIDES','WINEDEBUG','LD_LIBRARY_PATH']}
            env.update(MIDNIGHT_RUNTIME=str(runtime), MIDNIGHT_RUNNER=str(runner), CALLS=str(log))
            p = subprocess.run(['bash', str(SCRIPT)], env=env, capture_output=True, text=True)
            return p.returncode, log.read_text() if log.exists() else ''

    def test_window_and_server(self):
        code, calls = self.run_case()
        self.assertEqual(code, 0)
        self.assertIn('/desktop=Midnatsmysteriet,800x600', calls)
        self.assertIn('mm13main.exe', calls)
        self.assertTrue(calls.endswith('wineserver\n-w\n'))

    def test_launch_error_still_waits(self):
        code, calls = self.run_case(fail=True)
        self.assertEqual(code, 7)
        self.assertTrue(calls.endswith('wineserver\n-w\n'))

    def test_missing_exe(self):
        code, calls = self.run_case(missing='exe')
        self.assertNotEqual(code, 0)
        self.assertEqual(calls, '')

    def test_missing_cd(self):
        code, calls = self.run_case(missing='cd')
        self.assertNotEqual(code, 0)
        self.assertEqual(calls, '')

if __name__ == '__main__':
    unittest.main()
