import importlib.util
from pathlib import Path
import subprocess
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('runtime', Path(__file__).with_name('appimage_runtime.py'))
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)

class PrerequisiteTests(unittest.TestCase):
    def test_reports_all_missing_requirements(self):
        with patch.object(m.shutil, 'which', return_value=None), patch.object(m.Path, 'exists', return_value=False), patch.object(m.Path, 'is_file', return_value=False), patch.object(m, 'run') as run:
            with self.assertRaises(RuntimeError) as error:
                m.check_prerequisites(Path('/bundle'), 'windowed16')
        text = str(error.exception)
        for word in ('cdemu', 'udisksctl', 'findmnt', 'cp', 'gamescope', 'VHBA', 'Wine', 'Xephyr', 'ikke helt selvstændig'):
            self.assertIn(word, text)
        run.assert_not_called()

    def test_service_failure_is_reported_with_other_missing_items(self):
        for failure in (subprocess.CalledProcessError(1, ['cdemu', 'status'], stderr='no session bus'), subprocess.TimeoutExpired(['cdemu', 'status'], 10)):
            with self.subTest(failure=type(failure).__name__), patch.object(m.shutil, 'which', side_effect=lambda tool: None if tool == 'gamescope' else '/usr/bin/'+tool), patch.object(m.Path, 'exists', return_value=True), patch.object(m.Path, 'is_file', return_value=True), patch.object(m, 'run', side_effect=failure):
                with self.assertRaises(RuntimeError) as error:
                    m.check_prerequisites(Path('/bundle'), 'windowed16')
                self.assertIn('CDEmu-tjenesten', str(error.exception))
                self.assertIn('gamescope', str(error.exception))

    def test_main_check_uses_aggregate_and_does_not_create_state(self):
        with patch.object(m.sys, 'argv', ['AppRun', '--check']), patch.object(m.shutil, 'which', return_value=None), patch.object(m.Path, 'exists', return_value=False), patch.object(m.Path, 'is_file', return_value=False), patch.object(m.Path, 'mkdir') as mkdir:
            with self.assertRaises(RuntimeError) as error:
                m.main()
        self.assertIn('VHBA', str(error.exception))
        self.assertIn('cdemu', str(error.exception))
        mkdir.assert_not_called()

if __name__ == '__main__':
    unittest.main()
