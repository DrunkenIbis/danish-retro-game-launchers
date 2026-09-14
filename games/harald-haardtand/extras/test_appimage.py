import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent

class AppImageTests(unittest.TestCase):
    def test_seed_preserve_and_bundled_runtime(self):
        self.assertTrue((HERE / 'AppRun').is_file(), 'AppRun missing')
        with tempfile.TemporaryDirectory(prefix='harald bundle ') as t:
            root = Path(t)
            app = root / 'app'
            (app / 'game').mkdir(parents=True)
            (app / 'runtime').mkdir()
            for name in ('HARALD.EXE','HARALD.001','HARALD.002','HARALD.DIR','HIGH.DAT'):
                (app / 'game' / name).write_text('fixture')
            (app / 'harald.conf').write_text('mount c ./game\n')
            # Test-only executable: verifies cwd/config without real game media.
            binary = app / 'runtime/dosbox'
            binary.write_text('#!/bin/sh\ntest -f game/HARALD.EXE && test -f harald.conf\n')
            binary.chmod(0o755)
            shutil.copy2(HERE / 'AppRun', app / 'AppRun')
            env = dict(os.environ, XDG_DATA_HOME=str(root / 'state'))
            for i in range(2):
                r = subprocess.run(['bash', str(app / 'AppRun')], env=env, capture_output=True)
                self.assertEqual(r.returncode, 0, r.stderr)
                high = root / 'state/harald-haardtand/game/HIGH.DAT'
                if i == 0:
                    high.write_text('my score')
                self.assertEqual(high.read_text(), 'my score')
            self.assertEqual((app / 'game/HIGH.DAT').read_text(), 'fixture')

if __name__ == '__main__':
    unittest.main()
