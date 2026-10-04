import os
import unittest
from unittest.mock import patch
import display_runner

class FrameTransferTests(unittest.TestCase):
    def test_copy_mode_is_scoped_to_child_environment(self):
        with patch.dict(os.environ, {'OVERBOARD_COPY_FRAMES': '1'}, clear=True):
            self.assertTrue(hasattr(display_runner, 'xephyr_environment'))
            env = display_runner.xephyr_environment()
            self.assertEqual(env.get('XEPHYR_NO_SHM'), '1')
            self.assertNotIn('XEPHYR_NO_SHM', os.environ)

    def test_baseline_remains_available(self):
        with patch.dict(os.environ, {'OVERBOARD_COPY_FRAMES': '0'}, clear=True):
            self.assertTrue(hasattr(display_runner, 'xephyr_environment'))
            self.assertNotIn('XEPHYR_NO_SHM', display_runner.xephyr_environment())
