import os
from pathlib import Path
import unittest
from unittest.mock import patch
import display_runner


class StandaloneDisplayTests(unittest.TestCase):
    def test_explicit_runtime_paths_for_kernel_free_variant(self):
        with patch.dict(os.environ, OVERBOARD_WINE='/runner/bin/wine', OVERBOARD_XEPHYR='/usr/bin/Xephyr'):
            self.assertEqual(display_runner.runtime_paths(Path('/bundle')),
                             (Path('/runner/bin/wine'), Path('/usr/bin/Xephyr')))

    def test_maximizable_scaler_keeps_aspect_ratio(self):
        command = display_runner.gamescope_command('/python', '/script')
        self.assertEqual(command[command.index('-S') + 1], 'fit')
        self.assertNotIn('stretch', command)
        self.assertNotIn('-b', command)
        self.assertNotIn('-f', command)
