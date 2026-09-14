import os
from pathlib import Path
import subprocess
import tempfile
import unittest

GAME = Path(__file__).resolve().parents[1]

class LauncherTests(unittest.TestCase):
    def test_dry_run_has_no_side_effects(self):
        with tempfile.TemporaryDirectory(prefix='solur test ') as t:
            target = Path(t) / 'not-created'
            env = dict(os.environ, SOLUR_RUNTIME_DIR=str(target), SOLUR_DRY_RUN='1')
            r = subprocess.run(['bash', str(GAME / 'launch.sh')], env=env, capture_output=True, text=True)
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertIn('mm6.exe', r.stdout)
            self.assertFalse(target.exists())

if __name__ == '__main__':
    unittest.main()
