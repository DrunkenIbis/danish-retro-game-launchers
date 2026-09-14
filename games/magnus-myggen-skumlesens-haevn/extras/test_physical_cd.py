import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'physical_cd.sh'

class PhysicalCDTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.cd = self.root / 'cd'
        self.cd.mkdir()
        (self.cd / 'SETUP.EXE').touch()
        self.dev = self.root / 'device'
        self.dev.touch()
        self.runtime = self.root / 'runtime'
        self.prefix = self.runtime / 'prefix-ge'
        self.log = self.root / 'calls'
        self.env = dict(os.environ, PATH=str(self.bin) + ':' + os.environ['PATH'],
                        MM3_PHYSICAL_CD=str(self.cd), MM3_PHYSICAL_DEVICE=str(self.dev),
                        MM3_PHYSICAL_RUNTIME=str(self.runtime), MM3_PHYSICAL_WINE=str(self.bin / 'wine'),
                        CALL_LOG=str(self.log), MOCK_SOURCE=str(self.dev))
        self.env.pop('WINEDLLOVERRIDES', None)
        self.executable('stat', "#!/bin/sh\nprintf 'block special file\\n'\n")
        self.executable('findmnt', '#!/bin/sh\nprintf "%s\\n" "$MOCK_SOURCE"\n')
        helper = '''#!/usr/bin/env python3
import os,sys,json
from pathlib import Path
p=Path(os.environ['WINEPREFIX'])
with open(os.environ['CALL_LOG'],'a') as f:
 f.write(json.dumps([Path(sys.argv[0]).name,sys.argv[1:],os.getcwd(),os.environ.get('WINEDLLOVERRIDES','')])+'\\n')
if len(sys.argv)>1 and sys.argv[1]=='wineboot':
 assert not (p/'dosdevices').exists()
 (p/'dosdevices').mkdir(parents=True)
 (p/'drive_c').mkdir()
 (p/'system.reg').touch()
if sys.argv[-1].lower().endswith('mm3run.exe'):
 sys.exit(int(os.environ.get('GAME_EXIT','0')))
'''
        self.executable('wine', helper)
        self.executable('wineserver', helper)

    def executable(self, name, content):
        p = self.bin / name
        p.write_text(content)
        p.chmod(0o755)

    def installed(self):
        (self.prefix / 'dosdevices').mkdir(parents=True)
        game = self.prefix / 'drive_c/Program Files/IVANOFF/Skumlesens hævn/MM3RUN.EXE'
        game.parent.mkdir(parents=True)
        game.touch()
        (self.prefix / 'system.reg').touch()
        return game

    def run_mode(self, mode):
        return subprocess.run(['bash', str(SCRIPT), mode], env=self.env, text=True, capture_output=True, timeout=10)

    def calls(self):
        return [json.loads(x) for x in self.log.read_text().splitlines()]

    def test_dry_run_is_side_effect_free(self):
        r = self.run_mode('dry-run')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(self.runtime.exists())
        self.assertFalse(self.log.exists())

    def test_wrong_media_fails_before_wine(self):
        self.env['MOCK_SOURCE'] = str(self.cd)
        r = self.run_mode('setup')
        self.assertNotEqual(r.returncode, 0)
        self.assertFalse(self.log.exists())
        self.assertFalse(self.runtime.exists())

    def test_missing_game_fails_without_bootstrap(self):
        self.assertNotEqual(self.run_mode('game').returncode, 0)
        self.assertFalse(self.log.exists())

    def test_setup_initializes_then_launches_original(self):
        r = self.run_mode('setup')
        self.assertEqual(r.returncode, 0, r.stderr)
        calls = self.calls()
        self.assertEqual(calls[0][1][0], 'wineboot')
        self.assertIn('mscoree,mshtml=', calls[0][3])
        self.assertEqual(calls[-2][1], [str(self.cd / 'SETUP.EXE')])
        self.assertEqual(calls[-2][2], str(self.cd))
        self.assertEqual(calls[-1][:2], ['wineserver', ['-w']])
        self.assertEqual((self.prefix / 'dosdevices/e:').resolve(), self.cd)
        self.assertEqual((self.prefix / 'dosdevices/e::').resolve(), self.dev)
        self.assertEqual(sorted(x.name for x in self.cd.iterdir()), ['SETUP.EXE'])

    def test_nonzero_game_still_waits(self):
        game = self.installed()
        self.env['GAME_EXIT'] = '7'
        r = self.run_mode('game')
        self.assertEqual(r.returncode, 7, r.stderr)
        calls = self.calls()
        self.assertEqual(calls[-2][1], [str(game)])
        self.assertEqual(calls[-2][2], str(game.parent))
        self.assertEqual(calls[-1][:2], ['wineserver', ['-w']])
        self.assertFalse(any(c[1][0] == 'wineboot' for c in calls))

    def test_ambiguous_installation_fails(self):
        self.installed()
        (self.prefix / 'drive_c/Program Files/mm3run.exe').touch()
        self.assertNotEqual(self.run_mode('game').returncode, 0)
        self.assertFalse(self.log.exists())

    def test_kill_does_not_require_cd(self):
        self.installed()
        self.env['MM3_PHYSICAL_CD'] = '/not-present'
        self.assertEqual(self.run_mode('kill').returncode, 0)
        self.assertEqual([c[:2] for c in self.calls()], [['wineserver', ['-k']], ['wineserver', ['-w']]])

if __name__ == '__main__':
    unittest.main()
