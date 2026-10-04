import threading
import unittest
from types import SimpleNamespace as NS
from unittest.mock import Mock, patch
import display_runner


class DynamicWindowTests(unittest.TestCase):
    def test_follows_selected_desktop_through_resolution_changes(self):
        root = Mock()
        window = Mock()
        window.get_wm_name.return_value = 'OverboardKernelFree - Wine desktop'
        window.get_geometry.side_effect = [NS(width=640, height=480), NS(width=800, height=600)]
        root.query_tree.return_value = NS(children=[window])
        sizes = [NS(width_in_pixels=640, height_in_pixels=480), NS(width_in_pixels=800, height_in_pixels=600)]
        root.xrandr_get_screen_info.side_effect = [NS(sizes=sizes, size_id=1, config_timestamp=1), NS(sizes=sizes, size_id=0, config_timestamp=2)]
        root.xrandr_set_screen_config.return_value = NS(status=0)
        conn = Mock()
        conn.screen.return_value = NS(root=root)
        stop = Mock()
        stop.wait.side_effect = [False, False, True]
        errors = []
        with patch('Xlib.display.Display', return_value=conn):
            display_runner.watch(':99', stop, threading.Event(), errors,
                                 desktop_name='OverboardKernelFree - Wine desktop')
        self.assertEqual(errors, [])
        self.assertEqual([call.args[0] for call in root.xrandr_set_screen_config.call_args_list], [0, 1])
        conn.close.assert_called_once()
