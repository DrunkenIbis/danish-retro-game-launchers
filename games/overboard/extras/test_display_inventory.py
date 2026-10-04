"""Ensure PATH-spawned display helpers have both payloads and loader wrappers."""
import ast
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).parent


class DisplayInventoryTests(unittest.TestCase):
    def test_reaper_is_bundled_and_wrapped_with_all_display_executables(self):
        tree = ast.parse((HERE/'bundle_display_runtime.py').read_text())
        inventories = [ast.literal_eval(node.iter) for node in ast.walk(tree)
                       if isinstance(node, ast.For) and isinstance(node.target, ast.Name)
                       and node.target.id == 'name' and isinstance(node.iter, ast.Tuple)]
        self.assertEqual(len(inventories), 1)
        payloads = set(inventories[0])
        match = re.search(r'for name in ([^;]+); do install -m755 "\$HERE/portable-display"',
                          (HERE/'build_portable_appimage.sh').read_text())
        self.assertIsNotNone(match)
        assert match is not None
        wrappers = set(match.group(1).split())
        self.assertIn('gamescopereaper', payloads)
        self.assertIn('gamescopereaper', wrappers)
        self.assertEqual(payloads - {'python3.14'}, wrappers - {'python3'})

    def test_reaper_path_wrapper_uses_private_loader_and_inherited_display(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = Path(tmp)
            bindir = app/'usr/bin'
            bindir.mkdir(parents=True)
            wrapper = bindir/'gamescopereaper'
            shutil.copyfile(HERE/'portable-display', wrapper)
            wrapper.chmod(0o755)
            loader = app/'display/lib/ld-linux-x86-64.so.2'
            loader.parent.mkdir(parents=True)
            loader.write_text('#!/bin/sh\nprintf "ARG:%s\\n" "$@"\n/usr/bin/env\n')
            loader.chmod(0o755)
            env = dict(os.environ, PATH=str(bindir)+':/usr/bin:/bin',
                       DISPLAY=':77', WAYLAND_DISPLAY='private-wayland',
                       OVERBOARD_WINE_XDG_DATA_DIRS='/original/share',
                       VK_DRIVER_FILES='/private/icd.json')
            result = subprocess.run(['gamescopereaper', 'child-argument'], env=env,
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            lines = result.stdout.splitlines()
            self.assertEqual(lines[:4], ['ARG:--library-path', 'ARG:'+str(app/'display/lib'),
                                        'ARG:'+str(app/'display/bin/gamescopereaper'),
                                        'ARG:child-argument'])
            actual = dict(line.split('=', 1) for line in lines[4:] if '=' in line)
            for name in ('DISPLAY', 'WAYLAND_DISPLAY', 'OVERBOARD_WINE_XDG_DATA_DIRS', 'VK_DRIVER_FILES'):
                self.assertEqual(actual[name], env[name])
            self.assertNotIn('LD_LIBRARY_PATH', actual)
            self.assertEqual(actual['PATH'].split(':')[0], str(bindir))
