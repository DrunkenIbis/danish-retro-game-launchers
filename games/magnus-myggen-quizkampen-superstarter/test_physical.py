import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('launch_physical.sh')

class PhysicalLauncherTests(unittest.TestCase):
    def test_dry_run_is_side_effect_free_and_windowed(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, MMQ_PHYSICAL_RUNTIME=tmp + '/absent')
            result = subprocess.run(['bash', str(SCRIPT), 'dry-run'], env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('800x600', result.stdout)
            self.assertIn('Q112DK', result.stdout)
            self.assertFalse(Path(tmp, 'absent').exists())

if __name__ == '__main__':
    unittest.main()
