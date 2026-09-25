"""Synthetic launch tests: never run the game or real Wine."""
import os
import fcntl
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent

class RuntimeTests(unittest.TestCase):
    def test_writable_seed_and_bundled_pair(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); app = root/'App Dir'; state = root/'state'
            (app/'game/prefix/dosdevices').mkdir(parents=True)
            game = Path('drive_c/Program Files/EA GAMES/Battlefield Vietnam')
            (app/'game/prefix'/game).mkdir(parents=True)
            (app/'game/prefix'/game/'BfVietnam.exe').touch()
            (app/'game/prefix/system.reg').write_text('synthetic seed')
            (app/'game/prefix/dosdevices/d::').symlink_to('/dev/not-real')
            (app/'wine/bin').mkdir(parents=True)
            for name in ('wine', 'wineserver'):
                p = app/'wine/bin'/name
                p.write_text('#!/bin/sh\nprintf "%s|%s|%s|%s\\n" "$0" "$PWD" "$WINEPREFIX" "$*" >> "$TEST_LOG"\n')
                p.chmod(0o755)
            self.assertTrue((HERE/'AppRun').exists(), 'runtime launcher missing')
            shutil.copy2(HERE/'AppRun', app/'AppRun')
            env = dict(os.environ, BFV_APPIMAGE_STATE=str(state), TEST_LOG=str(root/'calls'))
            subprocess.run(['bash', str(app/'AppRun'), '+restart', '1'], env=env, check=True)
            self.assertEqual((state/'prefix/system.reg').read_text(), 'synthetic seed')
            self.assertFalse((state/'prefix/dosdevices/d::').is_symlink())
            self.assertEqual(os.readlink(state/'prefix/dosdevices/c:'), '../drive_c')
            lines = (root/'calls').read_text().splitlines()
            self.assertEqual(len(lines), 3)
            self.assertIn(str(app/'wine/bin/wineserver'), lines[0])
            self.assertIn(str(state/'prefix'/game), lines[1])
            self.assertIn('BfVietnam.exe +restart 1', lines[1])
            self.assertIn(str(app/'wine/bin/wineserver'), lines[2])
            self.assertTrue((app/'game/prefix/dosdevices/d::').is_symlink())
            # Persist user data and repair stale mappings again on steady launch.
            (state/'prefix/system.reg').write_text('user modified')
            (state/'prefix/dosdevices/e:').symlink_to('/old/mount')
            subprocess.run(['bash', str(app/'AppRun')], env=env, check=True)
            self.assertEqual((state/'prefix/system.reg').read_text(), 'user modified')
            self.assertFalse((state/'prefix/dosdevices/e:').is_symlink())
            # A busy state must reject a second launch before invoking any Wine.
            with (state/'.lock').open('w') as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                result = subprocess.run(['bash', str(app/'AppRun')], env=env, capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(b'already in use', result.stderr)
            self.assertEqual(len((root/'calls').read_text().splitlines()), 6)
            # XDG default and fresh state override use separate prefixes.
            env.pop('BFV_APPIMAGE_STATE')
            env['XDG_DATA_HOME'] = str(root/'xdg')
            subprocess.run(['bash', str(app/'AppRun')], env=env, check=True)
            self.assertTrue((root/'xdg/battlefield-vietnam-appimage/prefix/system.reg').is_file())
            # Reject relative overrides and bundle-local writable state.
            for invalid in ('relative-state', str(app/'state')):
                env['BFV_APPIMAGE_STATE'] = invalid
                result = subprocess.run(['bash', str(app/'AppRun')], env=env, capture_output=True)
                self.assertNotEqual(result.returncode, 0)

if __name__ == '__main__':
    unittest.main()
