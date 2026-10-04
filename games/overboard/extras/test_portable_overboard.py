import unittest
from pathlib import Path
import portable_overboard

class PortableTests(unittest.TestCase):
    def test_wayland_scales_and_x11_preserves_working_direct_path(self):
        self.assertEqual(portable_overboard.display_args({'WAYLAND_DISPLAY':'wayland-0'}), [])
        self.assertEqual(portable_overboard.display_args({}), ['--inner'])
        self.assertEqual(portable_overboard.display_args({'OVERBOARD_DISPLAY':'direct','WAYLAND_DISPLAY':'wayland-0'}), ['--inner'])

    def test_missing_payload_reported_without_creating_state(self):
        import tempfile
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)
            problems=portable_overboard.check(root)
            self.assertGreater(len(problems), 3)
            self.assertEqual(list(root.iterdir()), [])
