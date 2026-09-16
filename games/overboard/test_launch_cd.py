"""Read-only regression tests for the physical-CD launcher."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).with_name('launch_cd.sh')

class PhysicalLauncherTests(unittest.TestCase):
    def test_dry_run_has_no_side_effects(self):
        with tempfile.TemporaryDirectory() as tmp:
            prefix = Path(tmp) / 'absent'
            env = {k: v for k, v in os.environ.items() if not k.startswith(('WINE', 'OVERBOARD_'))}
            env['OVERBOARD_PHYSICAL_PREFIX'] = str(prefix)
            result = subprocess.run(['bash', str(SCRIPT), '--dry-run'], env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(str(prefix), result.stdout)
            self.assertIn('/dev/sr0', result.stdout)
            self.assertFalse(prefix.exists())

if __name__ == '__main__':
    unittest.main()
