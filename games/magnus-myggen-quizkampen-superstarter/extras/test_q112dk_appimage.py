#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import unittest
import tempfile
import os
import subprocess
import json
from unittest.mock import patch

MODULE = Path(__file__).with_name('q112dk_runtime.py')

class RuntimeTests(unittest.TestCase):
    def runtime(self):
        self.assertTrue(MODULE.exists(), 'Q112DK runtime has not been implemented')
        spec = importlib.util.spec_from_file_location('q112dk_runtime', MODULE)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_builder_uses_shared_helper_and_q112dk_inputs(self):
        builder = MODULE.with_name('build_q112dk_appimage.sh')
        self.assertTrue(builder.exists(), 'separate Q112DK builder missing')
        text = builder.read_text()
        for expected in ('scripts/wine-appimage-builder.sh', 'image-q112dk-ge/wineprefix32', 'Q112DK-original.iso', 'cp -a "$RUNNER"', 'wine_appimage_build_appimage'):
            self.assertIn(expected, text)
        subprocess.run(['bash', '-n', str(builder)], check=True)

    def test_check_is_read_only_and_missing_tool_is_explicit(self):
        runtime = self.runtime()
        self.assertTrue(hasattr(runtime, 'main'), 'CLI missing')
        with patch.object(runtime.shutil, 'which', return_value=None):
            with self.assertRaisesRegex(RuntimeError, 'cdemu'):
                runtime.main(['--check'])

    def test_selects_only_empty_device(self):
        runtime = self.runtime()
        self.assertEqual(runtime.empty_device('Devices status:\n0 True /other.iso\n1 False\n'), '1')
        self.assertIsNone(runtime.empty_device('0 True /other.iso\n'))

class LaunchTests(RuntimeTests):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='quizkampen-test-', dir=os.environ['TMPDIR'])
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.app = self.root/'app'
        self.state = self.root/'state'
        self.mount = self.root/'mounted disc'
        self.mount.mkdir()
        self.calls = []
        self.loaded = False
        self.added = False
        self.wrong_mount = False
        self.wine_exit = 0
        self.wait_fail = False
        prefix = self.app/'game/prefix'
        (prefix/'dosdevices').mkdir(parents=True)
        (prefix/'system.reg').write_text('seed')
        game = prefix/'drive_c/Program Files/Magnus & Myggen - Quizkampen'
        game.mkdir(parents=True)
        (game/'mm12main.EXE').write_text('fixture game')
        (prefix/'dosdevices/c:').symlink_to('../drive_c')
        (prefix/'dosdevices/e::').symlink_to('/dev/sr0')
        (prefix/'dosdevices/d:').symlink_to('/stale/disc')
        (self.app/'game/Q112DK.iso').write_bytes(b'fixture ISO')
        for name in ('wine', 'wineserver'):
            path = self.app/'wine/bin'/name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('fixture')
        self.runtime_module = self.runtime()
        self.real_run = subprocess.run

    def fake_run(self, args, **kwargs):
        args = [str(a) for a in args]
        self.calls.append(args)
        out = ''
        rc = 0
        if args[:2] == ['cdemu', 'status']:
            out = '0 True /other.iso\n'
            if self.added:
                out += '1 True '+str(self.state/'Q112DK.iso')+'\n' if self.loaded else '1 False\n'
        elif args[:2] == ['cdemu', 'add-device']:
            self.added = True
        elif args[:2] == ['cdemu', 'load']:
            assert args[2] == '1', 'must not touch loaded device 0'
            self.loaded = True
        elif args[:2] == ['cdemu', 'device-mapping']:
            out = '0 /dev/sr1 /dev/sg2\n1 /dev/sr99 /dev/sg99\n'
        elif args[0] == 'findmnt':
            out = json.dumps({'filesystems':[{'source':'/dev/sr0' if self.wrong_mount else '/dev/sr99', 'target':str(self.mount), 'label':'Q112DK'}]})
        elif args[0] == 'cp':
            return self.real_run(args, **kwargs)
        elif Path(args[0]).name == 'wine':
            env = kwargs['env']
            assert env['WINEARCH'] == 'win32'
            assert env['WINEDLLOVERRIDES'] == 'mscoree,mshtml='
            assert env['WINEPREFIX'] == str(self.state/'prefix')
            assert args[0] == str(self.app/'wine/bin/wine')
            assert not (self.state/'prefix/dosdevices/e::').is_symlink()
            if args[1] == 'explorer':
                assert args[2:] == ['/desktop=Quizkampen,800x600', r'C:\Program Files\Magnus & Myggen - Quizkampen\mm12main.EXE']
                rc = self.wine_exit
        elif Path(args[0]).name == 'wineserver' and args[-1] == '-w' and self.wait_fail:
            raise subprocess.TimeoutExpired(args, 20)
        elif args[:2] == ['cdemu', 'unload']:
            assert args[2] == '1'
            self.loaded = False
        if rc and kwargs.get('check'):
            raise subprocess.CalledProcessError(rc, args)
        return subprocess.CompletedProcess(args, rc, out, '')

    def launch(self):
        self.assertTrue(hasattr(self.runtime_module, 'launch'), 'launch not implemented')
        with patch.object(self.runtime_module.subprocess, 'run', side_effect=self.fake_run), patch.object(Path, 'is_block_device', return_value=True), patch.object(self.runtime_module.os, 'access', return_value=True):
            self.runtime_module.launch(self.app, self.state)

    def test_waits_for_mapping_block_node_and_read_permission(self):
        original = self.fake_run
        polls = []
        def delayed(args, **kwargs):
            result = original(args, **kwargs)
            if args[:2] == ['cdemu', 'device-mapping']:
                polls.append(args)
                if len(polls) == 1:
                    result.stdout = '0 /dev/sr1 /dev/sg2\n'
            if args[0] == 'findmnt':
                self.assertEqual(len(polls), 4, 'must not mount before readiness')
                self.assertEqual(args[3], '/dev/sr99')
            return result
        with patch.object(self.runtime_module.subprocess, 'run', side_effect=delayed), \
             patch.object(Path, 'is_block_device', side_effect=[False, True, True]), \
             patch.object(self.runtime_module.os, 'access', side_effect=[False, True]), \
             patch.object(self.runtime_module.time, 'sleep') as sleep:
            self.runtime_module.launch(self.app, self.state)
        self.assertEqual(len(polls), 4)
        self.assertEqual(sleep.call_count, 3)
        self.assertFalse(self.loaded)

    def test_readiness_timeout_cleans_owned_media_without_fallback(self):
        for unavailable in ('mapping', 'block', 'permission'):
            with self.subTest(unavailable=unavailable):
                self.calls.clear()
                clock = [0.0]
                original = self.fake_run
                def not_ready(args, **kwargs):
                    result = original(args, **kwargs)
                    if args[:2] == ['cdemu', 'device-mapping'] and unavailable == 'mapping':
                        result.stdout = '0 /dev/sr1 /dev/sg2\n'
                    return result
                def advance(seconds):
                    clock[0] += seconds
                with patch.object(self.runtime_module.subprocess, 'run', side_effect=not_ready), \
                     patch.object(Path, 'is_block_device', return_value=unavailable != 'block'), \
                     patch.object(self.runtime_module.os, 'access', return_value=False), \
                     patch.object(self.runtime_module.time, 'monotonic', side_effect=lambda: clock[0]), \
                     patch.object(self.runtime_module.time, 'sleep', side_effect=advance):
                    with self.assertRaisesRegex(RuntimeError, 'læsbart virtuelt blokdrev'):
                        self.runtime_module.launch(self.app, self.state)
                self.assertEqual(clock[0], 15.0, 'readiness should retry until its bounded deadline')
                self.assertFalse(self.loaded)
                self.assertIn(['cdemu', 'unload', '1'], self.calls)
                self.assertFalse(any(c[0] == 'findmnt' or Path(c[0]).name == 'wine' for c in self.calls))
                self.assertFalse(any(c[:2] == ['udisksctl', 'mount'] for c in self.calls))
                self.assertFalse((self.state/'prefix/dosdevices/d::').is_symlink())

    def test_removes_wine_autodiscovered_physical_drive(self):
        original = self.fake_run
        def autodiscover(args, **kwargs):
            result = original(args, **kwargs)
            if str(args[0]).endswith('/wine') and args[1] == 'reg':
                (self.state/'prefix/dosdevices/e::').symlink_to('/dev/sr0')
            return result
        self.fake_run = autodiscover
        self.launch()

    def test_cleanup_does_not_unload_replaced_media(self):
        original = self.fake_run
        def replaced(args, **kwargs):
            result = original(args, **kwargs)
            if str(args[0]).endswith('/wineserver') and args[-1] == '-w':
                self.replaced_media = True
            if args[:2] == ['cdemu', 'status'] and getattr(self, 'replaced_media', False):
                result.stdout = '0 True /other.iso\n1 True /someone-else.iso\n'
            return result
        self.fake_run = replaced
        self.launch()
        self.assertFalse(any(c[:2] == ['cdemu','unload'] for c in self.calls))

    def test_wait_failure_keeps_media_loaded(self):
        self.wait_fail = True
        with self.assertRaises(subprocess.TimeoutExpired):
            self.launch()
        self.assertTrue(self.loaded)
        self.assertFalse(any(c[:2] == ['cdemu','unload'] for c in self.calls))

    def test_failed_game_still_waits_then_cleans(self):
        self.wine_exit = 7
        with self.assertRaisesRegex(RuntimeError, 'kode 7'):
            self.launch()
        self.assertFalse(self.loaded)

    def test_repairs_same_size_corrupt_iso(self):
        self.state.mkdir()
        (self.state/'Q112DK.iso').write_bytes(b'corrupt ISO')
        self.launch()
        self.assertEqual((self.state/'Q112DK.iso').read_bytes(), b'fixture ISO')

    def test_rejects_wrong_mount_source_before_wine(self):
        self.wrong_mount = True
        with self.assertRaisesRegex(RuntimeError, 'Q112DK'):
            self.launch()
        self.assertFalse(any(Path(c[0]).name == 'wine' for c in self.calls))
        self.assertFalse(self.loaded)

    def test_seed_launch_wait_cleanup_without_touching_loaded_media(self):
        self.launch()
        self.assertEqual((self.state/'prefix/system.reg').read_text(), 'seed')
        self.assertEqual((self.state/'Q112DK.iso').read_bytes(), b'fixture ISO')
        self.assertFalse(self.loaded)
        wait = [i for i,c in enumerate(self.calls) if Path(c[0]).name == 'wineserver' and c[-1] == '-w']
        unload = next(i for i,c in enumerate(self.calls) if c[:2] == ['cdemu','unload'])
        self.assertTrue(wait and max(wait) < unload)
        self.assertFalse((self.state/'prefix/dosdevices/d::').is_symlink())
        self.assertTrue((self.app/'game/prefix/dosdevices/e::').is_symlink())

if __name__ == '__main__':
    unittest.main()
