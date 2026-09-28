"""Launcher contract tests with fake Wine; never boots the user's prefix."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


class LaunchTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='mm4-launch-')
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name) / 'repo med æ og mellemrum'
        self.here = self.root / 'games' / HERE.name
        self.here.mkdir(parents=True)
        self.script = self.here / 'launch.sh'
        if (HERE / self.script.name).exists():
            shutil.copy2(HERE / self.script.name, self.script)
        self.runtime = self.root / 'local/runtime/mm4-graphics'
        self.prefix = self.runtime / 'prefix'
        self.game = self.prefix / 'drive_c/Program Files/Skumlesens Skygge'
        self.game.mkdir(parents=True)
        (self.game / 'MM4.exe').write_bytes(b'fixture only')
        (self.prefix / 'system.reg').touch()
        self.cd = self.root / 'original CD'
        self.cd.mkdir()
        (self.cd / 'mm4.___').touch()
        self.device = self.root / 'fake-sr0'
        self.device.touch()
        dos = self.prefix / 'dosdevices'
        dos.mkdir()
        (dos / 'd:').symlink_to(self.cd)
        (dos / 'd::').symlink_to(self.device)
        self.bin = self.root / 'fake-bin'
        self.bin.mkdir()
        self.runner = self.root / 'local/runtime/mm4-thunk-fix/runner'
        (self.runner / 'bin').mkdir(parents=True)
        self.events = self.root / 'events.jsonl'
        self.env = os.environ.copy()
        for k in ('WINEPREFIX', 'WINEARCH', 'WINEDEBUG', 'WINEDLLOVERRIDES',
                  'WINELOADER', 'WINESERVER', 'LD_LIBRARY_PATH'):
            self.env.pop(k, None)
        self.env.update(PATH=str(self.bin) + ':' + os.environ['PATH'],
                        MM4_CD_MOUNT=str(self.cd), MM4_CD_DEVICE=str(self.device),
                        FIXTURE_EVENTS=str(self.events), FIXTURE_DEVICE=str(self.device),
                        # The pre-consolidation ISO launcher must not touch real media/Wine.
                        MM2_ISO=str(self.root / 'nonexistent-fixture.iso'),
                        MM2_WINE_BIN=str(self.runner / 'bin/wine'), MM2_SEVENZ_BIN='/usr/bin/true')
        stub = '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
name=Path(sys.argv[0]).name
with open(os.environ['FIXTURE_EVENTS'], 'a') as f:
 f.write(json.dumps(dict(name=name,args=sys.argv[1:],cwd=os.getcwd(),env={k:os.environ.get(k) for k in ['WINEPREFIX','WINEARCH','WINEDEBUG','WINEDLLOVERRIDES','WINELOADER','WINESERVER','LD_LIBRARY_PATH']}))+'\\n')
if name=='findmnt': print(os.environ['FIXTURE_DEVICE'])
elif name=='wine' and sys.argv[1:3]==['reg','query']:
 print('Version REG_SZ '+os.environ.get('FIXTURE_VERSION','winxp') if sys.argv[-1]=='Version' else 'UseSystemMemory REG_DWORD '+os.environ.get('FIXTURE_MEMORY','0x0'))
elif name=='wineserver' and sys.argv[1:]==['-w'] and os.environ.get('FIXTURE_BUSY')=='1': sys.exit(1)
elif name=='wine': sys.exit(int(os.environ.get('FIXTURE_EXIT','0')))
'''
        for p in (self.bin / 'findmnt', self.runner / 'bin/wine', self.runner / 'bin/wineserver'):
            p.write_text(stub)
            p.chmod(0o755)

    def run_launcher(self, *args):
        return subprocess.run(['bash', str(self.script), *args], env=self.env,
                              capture_output=True, text=True, timeout=10)

    def records(self):
        return [json.loads(s) for s in self.events.read_text().splitlines()] if self.events.exists() else []

    def test_launch_uses_verified_environment_and_desktop(self):
        self.env.update(WINEPREFIX='/wrong', WINEARCH='win64', WINEDEBUG='+relay', WINEDLLOVERRIDES='ddraw=n')
        result = self.run_launcher()
        self.assertEqual(result.returncode, 0, result.stderr)
        games = [r for r in self.records() if r['name']=='wine' and r['args'][0]=='explorer']
        self.assertEqual(len(games), 1)
        game = games[0]
        self.assertEqual(game['args'], ['explorer','/desktop=MM4GFX,1024x768',r'C:\Program Files\Skumlesens Skygge\MM4.exe'])
        self.assertEqual(game['cwd'], str(self.game))
        self.assertEqual(game['env']['WINEPREFIX'], str(self.prefix))
        self.assertEqual(game['env']['WINEARCH'], 'win32')
        self.assertEqual(game['env']['WINEDEBUG'], '-all')
        self.assertEqual(game['env']['WINEDLLOVERRIDES'], 'mscoree,mshtml=')
        self.assertTrue(any(r['name']=='wineserver' and r['args']==['-k'] for r in self.records()))

    def test_check_validates_without_starting_game(self):
        result = self.run_launcher('--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('klar', result.stdout.lower())
        self.assertFalse(any(r['args'] and r['args'][0]=='explorer' for r in self.records()))

    def test_missing_cd_stops_before_wine(self):
        (self.cd / 'mm4.___').unlink()
        result = self.run_launcher()
        self.assertEqual(result.returncode, 3)
        self.assertIn('original-CD', result.stderr)
        self.assertFalse(any(r['name']=='wine' for r in self.records()))

    def test_wrong_mount_stops_before_wine(self):
        self.env['FIXTURE_DEVICE'] = '/dev/wrong'
        result = self.run_launcher()
        self.assertEqual(result.returncode, 3)
        self.assertFalse(any(r['name']=='wine' for r in self.records()))

    def test_wrong_mapping_is_not_replaced(self):
        link = self.prefix / 'dosdevices/d:'
        link.unlink()
        link.symlink_to(self.root)
        self.assertEqual(self.run_launcher().returncode, 3)
        self.assertEqual(link.resolve(), self.root)

    def test_prefix_lock_is_respected_without_cleanup(self):
        import fcntl
        with (self.runtime / 'experiment.lock').open('w') as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            self.assertEqual(self.run_launcher().returncode, 4)
        self.assertFalse(any(r['name']=='wineserver' for r in self.records()))

    def test_wrong_windows_mode_does_not_launch_or_reconfigure(self):
        self.env['FIXTURE_VERSION'] = 'win98'
        self.assertEqual(self.run_launcher().returncode, 2)
        self.assertFalse(any(r['args'][0]=='explorer' or 'add' in r['args'] for r in self.records()))

    def test_nonzero_memory_with_leading_zero_is_rejected(self):
        self.env['FIXTURE_MEMORY'] = '0x01'
        self.assertEqual(self.run_launcher('--check').returncode, 2)

    def test_existing_server_is_not_killed(self):
        self.env['FIXTURE_BUSY'] = '1'
        self.assertEqual(self.run_launcher().returncode, 4)
        self.assertFalse(any(r['args']==['-k'] for r in self.records()))

    def test_alias_forwards_check_to_canonical_launcher(self):
        alias = self.here / 'launch_physical.sh'
        shutil.copy2(HERE / alias.name, alias)
        self.script = alias
        result = self.run_launcher('--check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('klar', result.stdout.lower())
        self.assertFalse(any(r['args'][0]=='explorer' for r in self.records()))

    def test_failure_propagates_and_cleans_own_prefix(self):
        self.env['FIXTURE_EXIT'] = '7'
        self.assertEqual(self.run_launcher().returncode, 7)
        self.assertTrue(any(r['name']=='wineserver' and r['args']==['-k'] for r in self.records()))


if __name__ == '__main__':
    unittest.main()
