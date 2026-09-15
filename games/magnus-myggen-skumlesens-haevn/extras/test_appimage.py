"""Headless launcher contract tests: fake GE only, never starts Wine."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
SLUG = 'magnus-myggen-skumlesens-haevn'
INSTALLED = Path('drive_c/Program Files/IVANOFF Interactive/Skumlesens hævn')


class AppRunTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / 'AppDir'
        self.seed = self.app / 'game/prefix'
        (self.seed / INSTALLED).mkdir(parents=True)
        (self.seed / INSTALLED / 'mm3run.exe').write_text('original')
        (self.seed / 'system.reg').write_text('original registry')
        (self.seed / 'dosdevices').mkdir()
        for name in ('d:', 'd::', 'e:', 'e::'):
            (self.seed / 'dosdevices' / name).symlink_to('/dev/stale')
        (self.app / 'game/cdrom').mkdir()
        self.bin = self.app / 'usr/wine-ge/bin'
        self.bin.mkdir(parents=True)
        wine = self.bin / 'wine'
        wine.write_text('''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
with open(os.environ['TRACE'], 'a') as f:
    f.write(json.dumps({'args':sys.argv[1:], 'cwd':os.getcwd(), 'prefix':os.environ['WINEPREFIX'], 'arch':os.environ['WINEARCH'], 'server':os.environ['WINESERVER'], 'dll':os.environ.get('WINEDLLPATH'), 'libs':os.environ['LD_LIBRARY_PATH']})+'\\n')
sys.exit(int(os.environ.get('WINE_STATUS', '0')))
''')
        wine.chmod(0o755)
        server = self.bin / 'wineserver'
        server.write_text('#!/bin/bash\nprintf "server %s\\n" "$*" >> "$TRACE"\nexit "${SERVER_STATUS:-0}"\n')
        server.chmod(0o755)
        self.env = dict(os.environ, XDG_DATA_HOME=str(self.root / 'data'), TRACE=str(self.root / 'trace'), WINESERVER='/host/bad', WINEDLLPATH='/host/bad', LD_LIBRARY_PATH='/host/bad')
        self.prefix = self.root / 'data' / SLUG / 'prefix'

    def run_app(self, **env):
        self.assertTrue((HERE / 'AppRun').is_file(), 'AppRun implementation missing')
        shutil.copy2(HERE / 'AppRun', self.app / 'AppRun')
        return subprocess.run(['bash', str(self.app / 'AppRun')], env=dict(self.env, **env), capture_output=True, text=True, timeout=10)

    def test_seed_persist_remap_and_ge_environment(self):
        result = self.run_app()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.prefix / 'system.reg').read_text(), 'original registry')
        record = json.loads((self.root / 'trace').read_text().splitlines()[0])
        self.assertEqual(record['cwd'], str(self.prefix / INSTALLED))
        self.assertEqual(record['args'], [str(self.prefix / INSTALLED / 'mm3run.exe')])
        self.assertEqual(record['arch'], 'win32')
        self.assertEqual(record['server'], str(self.bin / 'wineserver'))
        self.assertNotIn('/host/bad', str(record))
        self.assertIn(str(self.app / 'usr/wine-ge/lib'), record['libs'])
        self.assertIn(str(self.app / 'usr/wine-ge/lib64'), record['libs'])
        self.assertEqual((self.prefix / 'dosdevices/e:').resolve(), self.app / 'game/cdrom')
        for name in ('d:', 'd::', 'e::'):
            self.assertFalse((self.prefix / 'dosdevices' / name).is_symlink())
        save = self.prefix / INSTALLED / 'save.dat'
        save.write_text('keep me')
        (self.prefix / 'system.reg').write_text('updated registry')
        self.assertEqual(self.run_app().returncode, 0)
        self.assertEqual(save.read_text(), 'keep me')
        self.assertEqual((self.prefix / 'system.reg').read_text(), 'updated registry')
        self.assertFalse(list(self.prefix.parent.glob('.prefix.*')))

    def test_nonzero_wine_still_waits_server(self):
        result = self.run_app(WINE_STATUS='17', SERVER_STATUS='23')
        self.assertEqual(result.returncode, 17, result.stderr)
        self.assertEqual((self.root / 'trace').read_text().splitlines()[-1], 'server -w')

    def test_server_error_is_reported(self):
        result = self.run_app(SERVER_STATUS='23')
        self.assertEqual(result.returncode, 23, result.stderr)


class BuilderTests(unittest.TestCase):
    def test_isolated_source_and_output_overrides(self):
        text = (HERE / 'build_appimage.sh').read_text()
        self.assertIn('${MM3_APPIMAGE_RUNTIME:-', text)
        self.assertIn('${MM3_APPIMAGE_DIST:-', text)

    def test_private_full_ge_builder_contract(self):
        builder = HERE / 'build_appimage.sh'
        self.assertTrue(builder.is_file(), 'MM3 builder missing')
        text = builder.read_text()
        self.assertIn('source "$REPO/scripts/wine-appimage-builder.sh"', text)
        self.assertIn('wine_appimage_write_desktop_file', text)
        self.assertIn('wine_appimage_build_appimage', text)
        self.assertNotIn('wine_appimage_copy_wine_runtime', text)
        self.assertIn('cp -a "$GE" "$APPDIR/usr/wine-ge"', text)
        self.assertIn('b90f4a8b18967545fda78a445b27680a1642f1ef9488ced28b65398f2be7add2', text)
        self.assertIn('timeout 3 "$GE/bin/wineserver" -w', text)
        self.assertNotIn('wineserver" -k', text)


if __name__ == '__main__':
    unittest.main()
