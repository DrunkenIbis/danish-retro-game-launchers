import os
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent

class SecretWeaponsTests(unittest.TestCase):
    def test_appimage_relative_state_rejected(self):
        env = os.environ.copy()
        env['BF1942_SW_APPIMAGE_STATE'] = 'relative-state'
        result = subprocess.run(['bash', str(HERE/'extras/AppRun.secret-weapons')], env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('State directory must be absolute', result.stderr)

    def test_launcher_missing_expansion(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env['BF1942_SW_SIMPLE_RUNTIME'] = tmp+'/missing'
            result = subprocess.run(['bash', str(HERE/'launch_secret_weapons.sh')], env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Missing Secret Weapons game data', result.stderr)
            self.assertFalse(Path(tmp, 'missing').exists())

    def test_backup_accepts_expansion_label(self):
        env = os.environ.copy()
        env['BF1942_DDRESCUE'] = '/nonexistent/bf1942-test-ddrescue'
        result = subprocess.run(['bash', str(HERE/'backup-disc.sh'), 'DISC_4_SECRETWEAPONS'], env=env, capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('GNU ddrescue missing', result.stderr)

    def test_missing_seed_does_not_create_output(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env.update(BF1942_SW_SEED=tmp+'/missing', BF1942_SW_RUNTIME=tmp+'/output')
            result = subprocess.run(['bash', str(HERE/'install_secret_weapons.sh')], env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Missing installed seed', result.stderr)
            self.assertFalse(Path(tmp, 'output').exists())

if __name__ == '__main__':
    unittest.main()
