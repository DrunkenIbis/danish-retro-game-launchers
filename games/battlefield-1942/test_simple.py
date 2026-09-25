import os
from pathlib import Path
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent

class SimpleTests(unittest.TestCase):
    def test_launcher_missing_runtime(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env['BF1942_SIMPLE_RUNTIME'] = str(Path(tmp) / 'missing')
            p = subprocess.run(['bash', str(HERE / 'launch_simple.sh')], env=env, capture_output=True, text=True)
            self.assertNotEqual(p.returncode, 0)
            self.assertIn('Run prepare-simple.sh first', p.stderr)
            self.assertFalse(Path(env['BF1942_SIMPLE_RUNTIME']).exists())

    def test_missing_seed_does_not_create_runtime(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = os.environ.copy()
            env['BF1942_SIMPLE_SEED'] = str(Path(tmp) / 'missing')
            env['BF1942_SIMPLE_RUNTIME'] = str(Path(tmp) / 'output')
            p = subprocess.run(['bash', str(HERE / 'prepare-simple.sh')], env=env, capture_output=True, text=True)
            self.assertNotEqual(p.returncode, 0)
            self.assertIn('Missing installed seed', p.stderr)
            self.assertFalse(Path(env['BF1942_SIMPLE_RUNTIME']).exists())

if __name__ == '__main__':
    unittest.main()
