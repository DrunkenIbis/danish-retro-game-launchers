import os
import unittest
from unittest.mock import patch
import display_runner

class BackendTests(unittest.TestCase):
    def test_wayland_probe_keeps_fit_scaling(self):
        with patch.dict(os.environ, OVERBOARD_GAMESCOPE_BACKEND='wayland'):
            args = display_runner.gamescope_command('/python', '/script')
        self.assertEqual(args[args.index('--backend') + 1], 'wayland')
        self.assertEqual(args[args.index('-S') + 1], 'fit')

    def test_sdl_baseline_is_preserved(self):
        with patch.dict(os.environ, OVERBOARD_GAMESCOPE_BACKEND='sdl'):
            args = display_runner.gamescope_command('/python', '/script')
        self.assertEqual(args[args.index('--backend') + 1], 'sdl')

    def test_unknown_backend_rejected(self):
        with patch.dict(os.environ, OVERBOARD_GAMESCOPE_BACKEND='typo'):
            with self.assertRaises(ValueError):
                display_runner.gamescope_command('/python', '/script')
