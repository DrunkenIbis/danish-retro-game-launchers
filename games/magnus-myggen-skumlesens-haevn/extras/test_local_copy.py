import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'local_copy.sh'

class LocalCopyTests(unittest.TestCase):
    def test_dry_run_without_media_or_wine(self):
        with tempfile.TemporaryDirectory() as t:
            runtime = Path(t) / 'absent'
            env = dict(os.environ, MM3_LOCAL_RUNTIME=str(runtime), MM3_LOCAL_WINE='/absent/wine')
            p = subprocess.run(['bash', str(SCRIPT), 'dry-run'], env=env, capture_output=True, text=True)
            self.assertEqual(p.returncode, 0, p.stderr)
            self.assertFalse(runtime.exists())

    def test_game_maps_only_local_data_and_waits_after_error(self):
        with tempfile.TemporaryDirectory() as t:
            root = Path(t)
            runtime = root / 'runtime'
            prefix = runtime / 'prefix-ge'
            devices = prefix / 'dosdevices'
            devices.mkdir(parents=True)
            (prefix / 'system.reg').touch()
            game = prefix / 'drive_c/Program Files/IVANOFF/Skumlesens hævn/mm3run.exe'
            game.parent.mkdir(parents=True)
            game.touch()
            cd = runtime / 'cdrom'
            cd.mkdir()
            (cd / 'setup.exe').touch()
            for n in ['d:', 'd::', 'e:', 'e::']:
                (devices / n).symlink_to('/dev/sr0')
            bin = root / 'bin'
            bin.mkdir()
            log = root / 'log'
            for name, body in [('wine', 'printf "wine\\n" >> "$TEST_LOG"; exit 7'), ('wineserver', 'printf "server:%s\\n" "$1" >> "$TEST_LOG"')]:
                path = bin / name
                path.write_text('#!/bin/sh\n' + body + '\n')
                path.chmod(0o755)
            env = dict(os.environ, MM3_LOCAL_RUNTIME=str(runtime), MM3_LOCAL_WINE=str(bin/'wine'), TEST_LOG=str(log))
            p = subprocess.run(['bash', str(SCRIPT), 'game'], env=env, capture_output=True, text=True, timeout=10)
            self.assertEqual(p.returncode, 7, p.stderr)
            self.assertEqual((devices/'e:').resolve(), cd)
            for n in ['d:', 'd::', 'e::']:
                self.assertFalse((devices/n).is_symlink())
            self.assertEqual(log.read_text(), 'wine\nserver:-w\n')

if __name__ == '__main__':
    unittest.main()
