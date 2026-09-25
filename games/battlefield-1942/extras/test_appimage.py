import os
from pathlib import Path
import subprocess
import tempfile
import unittest
HERE=Path(__file__).resolve().parent
class AppImageTests(unittest.TestCase):
    def test_relative_state_rejected_before_write(self):
        env=os.environ.copy();env['BF1942_APPIMAGE_STATE']='relative-state'
        with tempfile.TemporaryDirectory() as d:
            p=subprocess.run(['bash',str(HERE/'AppRun')],env=env,cwd=d,capture_output=True,text=True)
            self.assertNotEqual(p.returncode,0)
            self.assertIn('State directory must be absolute',p.stderr)
            self.assertFalse((Path(d)/'relative-state').exists())
if __name__=='__main__':unittest.main()
