import os
import unittest
from unittest.mock import patch
import display_runner

class GlamorProbeTests(unittest.TestCase):
    def test_glamor_probe_preserves_depth_and_resolution_ownership(self):
        self.assertTrue(hasattr(display_runner, 'xephyr_command'))
        with patch.dict(os.environ, OVERBOARD_GLAMOR='1'):
            args = display_runner.xephyr_command('/Xephyr', 9)
            self.assertIn('-glamor', args)
            self.assertIn('1024x768x16', args)
            self.assertNotIn('-resizeable', args)
        with patch.dict(os.environ, OVERBOARD_GLAMOR='0'):
            self.assertNotIn('-glamor', display_runner.xephyr_command('/Xephyr', 9))
