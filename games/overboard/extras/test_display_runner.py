import importlib.util
from pathlib import Path
import unittest
from unittest import mock

class DisplayTests(unittest.TestCase):
    def test_windowed_command_and_supported_modes(self):
        p = Path(__file__).with_name('display_runner.py')
        self.assertTrue(p.exists(), 'display runner missing')
        spec = importlib.util.spec_from_file_location('display_runner', p)
        assert spec and spec.loader
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        args = m.gamescope_command('/python', '/runner.py')
        self.assertNotIn('-f', args)
        self.assertNotIn('-b', args)
        self.assertEqual(args[args.index('-S')+1], 'fit')
        self.assertEqual(m.mode_index([(1024,768),(640,480),(320,240)], (320,240)), 2)
        self.assertIsNone(m.mode_index([(640,480)], (800,600)))

    def test_wineserver_shutdown_timeout_still_cleans_resources(self):
        spec = importlib.util.spec_from_file_location(
            'display_runner', Path(__file__).with_name('display_runner.py'))
        assert spec and spec.loader
        m = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(m)
        for xephyr_timeout in (False, True):
            with self.subTest(xephyr_timeout=xephyr_timeout):
                stop, ready = mock.Mock(), mock.Mock()
                watcher, xserver = mock.Mock(), mock.Mock()
                timeout = m.subprocess.TimeoutExpired('wineserver -w', 20)
                if xephyr_timeout:
                    xserver.wait.side_effect = [
                        m.subprocess.TimeoutExpired('Xephyr', 5), 0]
                with (
                    mock.patch.dict(m.os.environ, WINEPREFIX='/mock/prefix'),
                    mock.patch.object(m.os, 'pipe', return_value=(100, 101)),
                    mock.patch.object(m.os, 'close') as close,
                    mock.patch.object(m.os, 'read', return_value=b'42\n'),
                    mock.patch.object(m.signal, 'signal'),
                    mock.patch.object(m.select, 'select', return_value=([100], [], [])),
                    mock.patch.object(m.threading, 'Event', side_effect=[stop, ready]),
                    mock.patch.object(m.threading, 'Thread', return_value=watcher),
                    mock.patch.object(m.subprocess, 'Popen', return_value=xserver),
                    mock.patch.object(m.subprocess, 'run', side_effect=[
                        mock.Mock(returncode=0), mock.Mock(), mock.Mock(), timeout]),
                ):
                    with self.assertRaises(m.subprocess.TimeoutExpired) as raised:
                        m.inner()
                    self.assertIs(raised.exception, timeout)
                    stop.set.assert_called_once_with()
                    watcher.join.assert_called_once_with(timeout=2)
                    xserver.terminate.assert_called_once_with()
                    if xephyr_timeout:
                        xserver.kill.assert_called_once_with()
                        self.assertEqual(xserver.wait.call_args_list,
                                         [mock.call(timeout=5), mock.call()])
                    else:
                        xserver.kill.assert_not_called()
                        xserver.wait.assert_called_once_with(timeout=5)
                    self.assertEqual(close.call_args_list,
                                     [mock.call(101), mock.call(100)])

if __name__ == '__main__': unittest.main()
