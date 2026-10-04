"""Runtime packaging regression tests (no game data required)."""
import importlib.util
from pathlib import Path
import unittest
HERE = Path(__file__).resolve().parent

class RuntimeTests(unittest.TestCase):
    def test_private_loaders_resolve_wine_data_after_relocation(self):
        import tempfile, shutil
        spec = importlib.util.spec_from_file_location('portable_runtime', HERE/'portable_runtime.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)/'bundle'
            data = root/'wine/share/wine/nls'
            data.mkdir(parents=True)
            (data/'l_intl.nls').write_bytes(b'nls fixture')
            loaders = ['i386-linux-gnu/ld-linux.so.2', 'x86_64-linux-gnu/ld-linux-x86-64.so.2']
            for name in loaders:
                loader = root/'portable/usr/lib'/name
                loader.parent.mkdir(parents=True)
                loader.touch()
            self.assertTrue(hasattr(module, 'link_wine_data'), 'private loader Wine data layout missing')
            module.link_wine_data(root/'portable')
            moved = Path(temporary)/'moved bundle'
            shutil.move(root, moved)
            for name in loaders:
                loader = (moved/'portable/usr/lib'/name).resolve()
                self.assertEqual((loader.parent/'../share/wine/nls/l_intl.nls').read_bytes(), b'nls fixture')

    def test_dependency_closure_selects_available_alternative(self):
        spec = importlib.util.spec_from_file_location('portable_runtime', HERE/'portable_runtime.py')
        self.assertTrue(Path(spec.origin).exists(), 'portable runtime dependency resolver missing')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        packages = {'root': {'Depends': 'missing | libc6 (>= 2.39), libx: any'},
                    'libc6': {}, 'libx': {}}
        self.assertEqual(module.closure(packages, ['root']), ['libc6', 'libx', 'root'])

    def test_portable_build_is_opt_in_and_reuses_shared_builder(self):
        source = (HERE/'build_appimage.sh').read_text()
        self.assertIn('BF1942_PORTABLE', source)
        self.assertIn('portable_runtime.py', source)
        self.assertIn('portable-packages.json', source)
        self.assertIn('wine-appimage-builder.sh', source)
        self.assertIn('Portable-x86_64.AppImage', source)

    def test_apprun_uses_private_entrypoints_when_bundled(self):
        import tempfile, shutil, subprocess, os
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            bundle = root/'bundle'
            for path in ['portable/bin', 'wine/bin', 'game/prefix/dosdevices', 'game/prefix/drive_c/Program Files/EA GAMES/Battlefield 1942']:
                (bundle/path).mkdir(parents=True)
            (bundle/'game/prefix/system.reg').touch()
            (bundle/'game/prefix/drive_c/Program Files/EA GAMES/Battlefield 1942/BF1942.exe').touch()
            shutil.copyfile(HERE/'AppRun', bundle/'AppRun')
            for name in ['wine', 'wineserver']:
                for runtime in ['wine', 'portable']:
                    file = bundle/runtime/'bin'/name
                    file.write_text('#!/bin/bash\n'+('exit 73\n' if runtime == 'wine' else 'exit 0\n'))
                    file.chmod(0o755)
            env = os.environ.copy();env['BF1942_APPIMAGE_STATE'] = str(root/'state')
            result = subprocess.run(['bash',str(bundle/'AppRun')], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn(str(bundle/'portable/bin/wine'), result.stdout)

    def test_wrapper_scopes_private_libraries_to_loader(self):
        import tempfile, shutil, subprocess, os
        self.assertTrue((HERE/'portable-wine').exists(), 'relocatable Wine wrapper missing')
        with tempfile.TemporaryDirectory(prefix='runtime with spaces ') as temporary:
            root = Path(temporary)
            (root/'portable/bin').mkdir(parents=True)
            (root/'portable/usr/lib/i386-linux-gnu').mkdir(parents=True)
            wrapper = root/'portable/bin/wine'
            shutil.copyfile(HERE/'portable-wine', wrapper)
            loader = root/'portable/usr/lib/i386-linux-gnu/ld-linux.so.2'
            loader.write_text('#!/bin/bash\nprintf "%s\\n" "$LD_LIBRARY_PATH" "$WINELOADER" "$WINESERVER" "$@"\n')
            loader.chmod(0o755)
            env = os.environ.copy(); env.pop('LD_LIBRARY_PATH', None)
            result = subprocess.run(['bash', str(wrapper), 'argument with spaces'], env=env, text=True, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            lines = result.stdout.splitlines()
            self.assertEqual(lines[0], '')
            self.assertEqual(lines[1], str(wrapper))
            self.assertEqual(lines[2], str(root/'portable/bin/wineserver'))
            self.assertIn('--library-path', lines)
            self.assertEqual(lines[-1], 'argument with spaces')

    def test_absolute_package_link_is_relocated_inside_runtime(self):
        import tarfile
        spec = importlib.util.spec_from_file_location('portable_runtime', HERE/'portable_runtime.py')
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        self.assertTrue(hasattr(module, 'runtime_filter'), 'safe relocation filter missing')
        info = tarfile.TarInfo('./etc/fonts/conf.d/test.conf')
        info.type = tarfile.SYMTYPE
        info.linkname = '/usr/share/fontconfig/conf.avail/test.conf'
        result = module.runtime_filter(info, '/isolated/runtime')
        self.assertEqual(result.linkname, '../../../usr/share/fontconfig/conf.avail/test.conf')

    def test_manifest_download_rejects_wrong_digest_before_extraction(self):
        import tempfile
        import json
        import subprocess
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            payload = root/'bad.deb'
            payload.write_bytes(b'not a package')
            manifest = root/'manifest.json'
            manifest.write_text(json.dumps([{'url': payload.as_uri(), 'sha256': '0'*64, 'filename': 'bad.deb'}]))
            result = subprocess.run(['python3', str(HERE/'portable_runtime.py'), 'build', str(manifest), str(root/'cache'), str(root/'output')], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('SHA256 mismatch', result.stderr)
            self.assertFalse((root/'output').exists())

if __name__ == '__main__': unittest.main()
