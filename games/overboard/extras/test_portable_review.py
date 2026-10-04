"""Synthetic packaging regressions; never launches Wine or a real display."""
import os
from pathlib import Path
import tempfile
import unittest
import shutil
import subprocess

import portable_overboard
import display_runner
import bundle_display_runtime
from unittest import mock


class TemplateLinkTests(unittest.TestCase):
    def test_nested_windows_templates_link_is_sanitized(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)/'prefix'
            target = Path(tmp)/'private-templates'
            target.mkdir()
            (target/'private.txt').write_text('not payload')
            link = root/'drive_c/users/test/AppData/Roaming/Microsoft/Windows/Templates'
            link.parent.mkdir(parents=True)
            link.symlink_to(target, target_is_directory=True)
            portable_overboard.sanitize_prefix(root)
            self.assertFalse(link.is_symlink())
            self.assertEqual(list(link.iterdir()), [])
            self.assertTrue((target/'private.txt').exists())


class DependencyTests(unittest.TestCase):
    def test_ldd_failure_is_not_treated_as_empty_dependency_closure(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as tmp:
            source = Path(tmp)/'not-an-elf'
            source.write_text('#!/bin/sh\nexit 0\n')
            with self.assertRaisesRegex(ValueError, 'ldd failed'):
                bundle_display_runtime.elf_dependencies(source)


class WineEnvironmentTests(unittest.TestCase):
    def test_wine_boundary_removes_display_runtime_without_changing_display_env(self):
        source = {'VK_DRIVER_FILES': '/elf64/icd.json',
                  'VK_ICD_FILENAMES': '/another/icd.json',
                  '__EGL_VENDOR_LIBRARY_FILENAMES': '/elf64/egl.json',
                  '__EGL_VENDOR_LIBRARY_DIRS': '/elf64/egl',
                  'LIBGL_DRIVERS_PATH': '/elf64/dri',
                  'GAMESCOPE_SCRIPT_PATH': '/bundled/scripts',
                  'XDG_DATA_DIRS': '/elf64/share:/original/share',
                  'OVERBOARD_WINE_XDG_DATA_DIRS': '/original/share',
                  'WAYLAND_DISPLAY': 'wayland-0', 'DISPLAY': ':42',
                  'WINEDLLOVERRIDES': 'winmm=n,b'}
        with mock.patch.dict(os.environ, source, clear=True):
            env = display_runner.wine_environment()
            self.assertEqual(dict(os.environ), source)
            self.assertEqual(display_runner.xephyr_environment(), source)
        for name in ('VK_DRIVER_FILES', 'VK_ICD_FILENAMES', '__EGL_VENDOR_LIBRARY_FILENAMES',
                     '__EGL_VENDOR_LIBRARY_DIRS', 'LIBGL_DRIVERS_PATH', 'GAMESCOPE_SCRIPT_PATH',
                     'WAYLAND_DISPLAY'):
            self.assertNotIn(name, env)
        self.assertEqual(env['XDG_DATA_DIRS'], '/original/share')
        self.assertEqual(env['DISPLAY'], ':42')
        self.assertEqual(env['WINEDLLOVERRIDES'], 'winmm=n,b;winevulkan=')



class DisplayWrapperTests(unittest.TestCase):
    def test_gamescope_uses_bundled_scripts_and_rejects_empty_directory(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as tmp:
            app = Path(tmp)
            (app/'usr/bin').mkdir(parents=True)
            wrapper = app/'usr/bin/gamescope'
            shutil.copyfile(Path(__file__).with_name('portable-display'), wrapper)
            wrapper.chmod(0o755)
            loader = app/'display/lib/ld-linux-x86-64.so.2'
            loader.parent.mkdir(parents=True)
            loader.write_text('#!/bin/sh\nexec /usr/bin/env\n')
            loader.chmod(0o755)
            scripts = app/'display/share/gamescope/scripts'
            scripts.mkdir(parents=True)
            (scripts/'test.lua').write_text('-- fixture')
            env = dict(os.environ, GAMESCOPE_SCRIPT_PATH='/host/scripts', XDG_DATA_DIRS='/host/data')
            env.pop('OVERBOARD_WINE_XDG_DATA_DIRS', None)
            result = subprocess.run([str(wrapper)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            actual = dict(line.split('=', 1) for line in result.stdout.splitlines() if '=' in line)
            self.assertEqual(actual['GAMESCOPE_SCRIPT_PATH'], str(scripts))
            self.assertEqual(actual['OVERBOARD_WINE_XDG_DATA_DIRS'], '/host/data')
            # Gamescope -> bundled Python keeps display settings intact until
            # wine_environment() explicitly crosses the Wine-only boundary.
            python_wrapper = wrapper.with_name('python3')
            shutil.copyfile(wrapper, python_wrapper)
            python_wrapper.chmod(0o755)
            python_result = subprocess.run([str(python_wrapper)], env=actual,
                                           capture_output=True, text=True)
            self.assertEqual(python_result.returncode, 0, python_result.stderr)
            python_env = dict(line.split('=', 1) for line in python_result.stdout.splitlines() if '=' in line)
            self.assertEqual(python_env['OVERBOARD_WINE_XDG_DATA_DIRS'], '/host/data')
            self.assertEqual(python_env['VK_DRIVER_FILES'], actual['VK_DRIVER_FILES'])
            self.assertEqual(python_env['XDG_DATA_DIRS'], actual['XDG_DATA_DIRS'])
            (scripts/'test.lua').unlink()
            result = subprocess.run([str(wrapper)], env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('scripts', result.stderr)


class PrefixTests(unittest.TestCase):
    def test_user_folder_links_replaced_without_copying_personal_files(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as tmp:
            root = Path(tmp)
            personal = root/'personal'
            personal.mkdir()
            (personal/'secret').write_text('do not copy')
            prefix = root/'prefix'
            user = prefix/'drive_c/users/test'
            user.mkdir(parents=True)
            for name in ('Documents', 'My Documents', 'Desktop', 'Music', 'Pictures', 'Videos', 'Downloads'):
                (user/name).symlink_to(personal, target_is_directory=True)
            drives = prefix/'dosdevices'
            drives.mkdir()
            (drives/'c:').symlink_to('../drive_c')
            (drives/'z:').symlink_to('/')
            portable_overboard.sanitize_prefix(prefix)
            for path in user.iterdir():
                self.assertFalse(path.is_symlink())
                self.assertEqual(list(path.iterdir()), [])
            self.assertEqual((personal/'secret').read_text(), 'do not copy')
            self.assertFalse((drives/'z:').is_symlink())
            self.assertEqual((drives/'c:').resolve(), prefix/'drive_c')

    def test_unknown_escape_is_rejected(self):
        with tempfile.TemporaryDirectory(dir=Path(__file__).parent) as tmp:
            prefix = Path(tmp)/'prefix'
            prefix.mkdir()
            (prefix/'unexpected').symlink_to('../outside')
            with self.assertRaisesRegex(ValueError, 'Escaping prefix link'):
                portable_overboard.sanitize_prefix(prefix)
