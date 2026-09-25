"""Synthetic launch tests: never run the game or real Wine."""
import os
import fcntl
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

HERE = Path(__file__).resolve().parent

class BuildTests(unittest.TestCase):
    def test_build_mode_outputs_are_separate(self):
        script = (HERE/'build_appimage.sh').read_text().split('SEED=')[0]
        def config(*args):
            result = subprocess.run(
                ['bash', '-c', script + '\nprintf "%s\\n" "$PROJECT_NAME" "$APPDIR" "$CACHE_DIR" "$OUTPUT_APPIMAGE" "$MODE"',
                 str(HERE/'build_appimage.sh'), *args], capture_output=True, text=True,
                env={k: v for k, v in os.environ.items() if k not in ('APPDIR', 'CACHE_DIR', 'DIST_DIR')})
            self.assertEqual(result.returncode, 0, result.stderr)
            return result.stdout.splitlines()
        default = config()
        windowed = config('--windowed')
        self.assertNotEqual(default[1], windowed[1])
        self.assertNotEqual(default[2], windowed[2])
        self.assertEqual(default[3].split('/')[-1], 'Battlefield-Vietnam-1.21-SiMPLE-x86_64.AppImage')
        self.assertEqual(windowed[3].split('/')[-1], 'Battlefield-Vietnam-1.21-SiMPLE-Windowed-x86_64.AppImage')
        self.assertEqual(default[4], 'fullscreen')
        self.assertEqual(windowed[4], 'windowed')
        wrapper = HERE/'build_appimage_windowed.sh'
        self.assertTrue(wrapper.is_file())
        self.assertIn('build_appimage.sh" --windowed', wrapper.read_text())

class NormalizationSafetyTests(unittest.TestCase):
    def test_symlinks_and_hardlinks_do_not_modify_outside_files(self):
        from normalize_windowed import normalize, PROFILES
        for kind in ('ancestor', 'profile', 'video', 'backup', 'hardlink'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                prefix = root/'prefix'
                profile = prefix/PROFILES/'Custom'
                profile.mkdir(parents=True)
                outside = root/'outside'
                outside.mkdir()
                original = b'game.setGameDisplayMode 2560 1080 16 1\n'
                target = outside/'Video.con'
                target.write_bytes(original)
                video = profile/'Video.con'
                if kind == 'ancestor':
                    shutil.rmtree(prefix/'drive_c')
                    (prefix/'drive_c').symlink_to(outside, target_is_directory=True)
                elif kind == 'profile':
                    profile.rmdir()
                    profile.symlink_to(outside, target_is_directory=True)
                elif kind == 'video':
                    video.symlink_to(target)
                elif kind == 'hardlink':
                    os.link(target, video)
                else:
                    video.write_bytes(original)
                    (profile/'Video.con.before-window-resolution').symlink_to(target)
                if kind in ('ancestor', 'video'):
                    with self.assertRaises(OSError):
                        normalize(prefix)
                else:
                    normalize(prefix)
                self.assertEqual(target.read_bytes(), original)
                if kind in ('backup', 'hardlink'):
                    self.assertEqual(video.read_bytes(), original.replace(b'2560 1080', b'1024 768'))

class RuntimeTests(unittest.TestCase):
    def test_writable_seed_and_bundled_pair(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp); app = root/'App Dir'; state = root/'state'
            (app/'game/prefix/dosdevices').mkdir(parents=True)
            game = Path('drive_c/Program Files/EA GAMES/Battlefield Vietnam')
            (app/'game/prefix'/game).mkdir(parents=True)
            (app/'game/prefix'/game/'BfVietnam.exe').touch()
            video_rel = game/'Mods/BfVietnam/settings/Profiles/Custom/Video.con'
            seed_video = app/'game/prefix'/video_rel
            seed_video.parent.mkdir(parents=True)
            original = b'rem keep settings\r\ngame.setGameDisplayMode 2560 1080 32 0\r\ngame.setGraphicsQuality 2\r\n'
            expected = original.replace(b'2560 1080', b'1024 768')
            seed_video.write_bytes(original)
            if (HERE/'normalize_windowed.py').exists():
                shutil.copy2(HERE/'normalize_windowed.py', app/'normalize_windowed.py')
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
            # A build-selected virtual desktop has its own default state.
            (app/'launch-mode').write_text('windowed\n')
            subprocess.run(['bash', str(app/'AppRun'), '+restart', '1'], env=env, check=True)
            windowed = root/'xdg/battlefield-vietnam-windowed-appimage'
            self.assertTrue((windowed/'prefix/system.reg').is_file())
            video = windowed/'prefix'/video_rel
            backup = video.with_name('Video.con.before-window-resolution')
            self.assertEqual(video.read_bytes(), expected)
            self.assertEqual(backup.read_bytes(), original)
            self.assertEqual(seed_video.read_bytes(), original)
            self.assertEqual((state/'prefix'/video_rel).read_bytes(), original)
            self.assertFalse((state/'prefix'/video_rel).with_name(backup.name).exists())
            # Existing state is corrected each start; original backup is immutable.
            video.write_bytes(expected.replace(b'1024 768', b'1920 1080'))
            subprocess.run(['bash', str(app/'AppRun'), '+restart', '1'], env=env, check=True)
            self.assertEqual(video.read_bytes(), expected)
            self.assertEqual(backup.read_bytes(), original)
            calls = (root/'calls').read_text().splitlines()
            self.assertEqual(calls[-2].split('|')[3],
                             f'explorer /desktop=BattlefieldVietnam,1024x768 {windowed}/prefix/{game}/BfVietnam.exe +restart 1')
            self.assertEqual(calls[-2].split('|')[1], str(windowed/'prefix'/game))
            self.assertIn(str(app/'wine/bin/wineserver'), calls[-1])
            # Stopped-prefix refusal must precede profile edits or game startup.
            video.write_bytes(original)
            server = app/'wine/bin/wineserver'
            server_script = server.read_text()
            server.write_text('#!/bin/sh\nexit 7\n')
            before = (root/'calls').read_text()
            result = subprocess.run(['bash', str(app/'AppRun')], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(video.read_bytes(), original)
            self.assertEqual((root/'calls').read_text(), before)
            server.write_text(server_script)
            # Explicit override remains supported in either variant.
            env['BFV_APPIMAGE_STATE'] = str(state)
            subprocess.run(['bash', str(app/'AppRun')], env=env, check=True)
            self.assertEqual((state/'prefix/system.reg').read_text(), 'user modified')
            # Bad config must fail before running any Wine.
            (app/'launch-mode').write_text('invalid\n')
            before = (root/'calls').read_text()
            result = subprocess.run(['bash', str(app/'AppRun')], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual((root/'calls').read_text(), before)
            (app/'launch-mode').write_text('fullscreen\n')
            # Reject relative overrides and bundle-local writable state.
            for invalid in ('relative-state', str(app/'state')):
                env['BFV_APPIMAGE_STATE'] = invalid
                result = subprocess.run(['bash', str(app/'AppRun')], env=env, capture_output=True)
                self.assertNotEqual(result.returncode, 0)

if __name__ == '__main__':
    unittest.main()
