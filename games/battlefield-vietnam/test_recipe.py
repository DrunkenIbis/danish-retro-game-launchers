#!/usr/bin/env python3
"""Automated recipe tests using synthetic ISO fixtures, NOT gameplay evidence."""
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent


def record(name, sector, size, directory=False):
    n = 33 + len(name)
    n += n % 2
    r = bytearray(n)
    r[0] = n
    struct.pack_into('<I', r, 2, sector)
    struct.pack_into('>I', r, 6, sector)
    struct.pack_into('<I', r, 10, size)
    struct.pack_into('>I', r, 14, size)
    r[25] = 2 if directory else 0
    r[28:32] = b'\x01\x00\x00\x01'
    r[32] = len(name)
    r[33:33+len(name)] = name
    return r


def fixture(path):
    image = bytearray(32*2048)
    def directory(sector, entries):
        data = record(b'\0', sector, 2048, True) + record(b'\1', sector, 2048, True)
        for e in entries:
            data += e
        image[sector*2048:sector*2048+len(data)] = data
    sample = b'synthetic cabinet bytes for recipe tests only'
    helpfile = b'synthetic help file'
    for sector, kind, root in ((16, 1, 20), (17, 2, 21)):
        d = bytearray(2048)
        d[:7] = bytes([kind])+b'CD001\x01'
        d[40:72] = b'BFV_3'.ljust(32, b' ')
        d[88:91] = b'%/E' if kind == 2 else b'\0\0\0'
        d[156:190] = record(b'\0', root, 2048, True)
        image[sector*2048:(sector+1)*2048] = d
    image[18*2048:18*2048+7] = b'\xffCD001\x01'
    directory(20, [record(b'SAMPLE.CAB;1',24,len(sample)),record(b'EREG',22,2048,True)])
    directory(21, [record('sample.cab;1'.encode('utf-16-be'),24,len(sample)),record('eReg'.encode('utf-16-be'),23,2048,True)])
    directory(22, [record(b'HELP.TXT;1',25,len(helpfile))])
    directory(23, [record('Help.txt;1'.encode('utf-16-be'),25,len(helpfile))])
    image[24*2048:24*2048+len(sample)] = sample
    image[25*2048:25*2048+len(helpfile)] = helpfile
    path.write_bytes(image)
    return sample, helpfile


class RecipeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(dir=os.environ.get('TMPDIR'))
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.iso = self.root/'fixture.iso'
        self.sample, self.helpfile = fixture(self.iso)
        self.out = self.root/'out'

    def run_script(self, script, *args):
        return subprocess.run([sys.executable,str(HERE/script),*map(str,args)],capture_output=True,text=True,timeout=15)

    def stage(self, *extra):
        return self.run_script('stage-disc-cab.py','--device',self.iso,'--label','BFV_3','--output-dir',self.out,*extra)

    def test_cab_and_existing_preservation(self):
        r=self.stage('--cab','sample.cab'); self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual((self.out/'sample.cab').read_bytes(),self.sample)
        r=self.stage('--cab','sample.cab'); self.assertNotEqual(r.returncode,0)
        self.assertEqual((self.out/'sample.cab').read_bytes(),self.sample)

    def test_resume_verifies_partial(self):
        self.out.mkdir(); p=self.out/'sample.cab.partial'; p.write_bytes(self.sample[:5])
        r=self.stage('--cab','sample.cab','--resume'); self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual((self.out/'sample.cab').read_bytes(),self.sample)

    def test_resume_rejects_wrong_partial(self):
        self.out.mkdir(); p=self.out/'sample.cab.partial'; p.write_bytes(b'wrong')
        r=self.stage('--cab','sample.cab','--resume'); self.assertNotEqual(r.returncode,0)
        self.assertEqual(p.read_bytes(),b'wrong')

    def test_resume_empty_partial(self):
        self.out.mkdir()
        partial = self.out/'sample.cab.partial'
        partial.touch()
        r = self.stage('--cab', 'sample.cab', '--resume')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.out/'sample.cab').read_bytes(), self.sample)
        self.assertFalse(partial.exists())

    def test_resume_rejects_partial_symlinks(self):
        for content in (b'', self.sample[:5], self.sample, None):
            with self.subTest(content=content), tempfile.TemporaryDirectory(dir=self.root) as folder:
                self.out = Path(folder)/'out'
                self.out.mkdir()
                outside = Path(folder)/'outside'
                if content is not None:
                    outside.write_bytes(content)
                partial = self.out/'sample.cab.partial'
                partial.symlink_to(outside)
                r = self.stage('--cab', 'sample.cab', '--resume')
                self.assertNotEqual(r.returncode, 0, r.stdout)
                self.assertTrue(partial.is_symlink())
                self.assertFalse((self.out/'sample.cab').is_symlink())
                self.assertFalse((self.out/'sample.cab').exists())
                if content is not None:
                    self.assertEqual(outside.read_bytes(), content)
                else:
                    self.assertFalse(outside.exists())

    def stage_directory(self):
        return self.run_script('stage-disc-directory.py', '--device', self.iso,
                               '--label', 'BFV_3', '--directory', 'eReg',
                               '--output-dir', self.out, '--manifest', self.root/'manifest.json')

    def test_stagers_reject_symlinked_output_ancestors(self):
        for script in ('cab', 'directory'):
            for location in ('above-root', 'root', 'nested'):
                with self.subTest(script=script, location=location), tempfile.TemporaryDirectory(dir=self.root) as folder:
                    base = Path(folder)
                    outside = base/'outside'
                    outside.mkdir()
                    self.out = base/'out'
                    if location == 'above-root':
                        (base/'alias').symlink_to(outside, target_is_directory=True)
                        self.out = base/'alias'/'out'
                    elif location == 'root':
                        self.out.symlink_to(outside, target_is_directory=True)
                    else:
                        self.out.mkdir()
                        (self.out/'eReg').symlink_to(outside, target_is_directory=True)
                    r = self.stage('--file', 'eReg/Help.txt') if script == 'cab' else self.stage_directory()
                    self.assertNotEqual(r.returncode, 0, r.stdout)
                    self.assertEqual(list(outside.iterdir()), [])

    def test_stagers_preserve_symlinked_destination(self):
        for script in ('cab', 'directory'):
            for exists in (False, True):
                with self.subTest(script=script, exists=exists), tempfile.TemporaryDirectory(dir=self.root) as folder:
                    self.out = Path(folder)/'out'
                    (self.out/'eReg').mkdir(parents=True)
                    outside = Path(folder)/'outside'
                    if exists:
                        outside.write_bytes(self.helpfile)
                    target = self.out/'eReg/Help.txt'
                    target.symlink_to(outside)
                    r = self.stage('--file', 'eReg/Help.txt') if script == 'cab' else self.stage_directory()
                    self.assertNotEqual(r.returncode, 0, r.stdout)
                    self.assertTrue(target.is_symlink())
                    if exists:
                        self.assertEqual(outside.read_bytes(), self.helpfile)
                    else:
                        self.assertFalse(outside.exists())

    def test_directory_rejects_partial_symlinks(self):
        (self.out/'eReg').mkdir(parents=True)
        outside = self.root/'outside'
        outside.write_bytes(b'preserve')
        partial = self.out/'eReg/Help.txt.partial'
        partial.symlink_to(outside)
        r = self.stage_directory()
        self.assertNotEqual(r.returncode, 0)
        self.assertTrue(partial.is_symlink())
        self.assertEqual(outside.read_bytes(), b'preserve')
        self.assertFalse((self.out/'eReg/Help.txt').exists())

    def test_directory_rejects_manifest_symlink_parent(self):
        outside = self.root/'outside'
        outside.mkdir()
        alias = self.root/'alias'
        alias.symlink_to(outside, target_is_directory=True)
        r = self.run_script('stage-disc-directory.py', '--device', self.iso,
                            '--label', 'BFV_3', '--directory', 'eReg',
                            '--output-dir', self.out, '--manifest', alias/'manifest.json')
        self.assertNotEqual(r.returncode, 0, r.stdout)
        self.assertEqual(list(outside.iterdir()), [])

    def test_mapped_launcher_rejects_relative_paths(self):
        for runtime, wine in (('relative', '/missing/wine'), (str(self.root/'runtime'), 'relative/wine')):
            with self.subTest(runtime=runtime, wine=wine):
                env = dict(os.environ, BFV_IMAGE_RUNTIME=runtime, BFV_WINE=wine)
                r = subprocess.run(['bash', str(HERE/'launch_mapped.sh')], env=env,
                                   capture_output=True, text=True, timeout=15)
                self.assertNotEqual(r.returncode, 0)
                self.assertIn('absolute', r.stderr)
                self.assertFalse((self.root/'runtime').exists())

    def test_mapped_launcher_rejects_physical_and_preserved_prefix(self):
        protected = self.root/'runtimes/battlefield-vietnam/physical-ge7'
        for kind in ('direct', 'preserved', 'alias', 'prefix-alias', 'override'):
            with self.subTest(kind=kind), tempfile.TemporaryDirectory(dir=self.root) as folder:
                runtime = Path(folder)/'diagnostic'
                physical = protected
                if kind == 'direct':
                    runtime = protected
                elif kind == 'preserved':
                    runtime = protected/'prefix-gameplay-confirmed'
                elif kind == 'alias':
                    runtime.symlink_to(protected, target_is_directory=True)
                elif kind == 'prefix-alias':
                    runtime.mkdir()
                    (runtime/'prefix').symlink_to(protected/'prefix-installed-original', target_is_directory=True)
                else:
                    physical = runtime
                env = dict(os.environ, RETRO_GAME_RUNTIME_DIR=str(self.root/'runtimes'),
                           BFV_RUNTIME=str(physical), BFV_IMAGE_RUNTIME=str(runtime), BFV_WINE='/missing/wine')
                r = subprocess.run(['bash', str(HERE/'launch_mapped.sh')], env=env,
                                   capture_output=True, text=True, timeout=15)
                self.assertNotEqual(r.returncode, 0)
                self.assertIn('Refusing physical/preserved prefix', r.stderr)
                self.assertFalse(protected.exists())
                self.assertFalse((runtime/'logs').exists())

    def test_folder_launcher_rejects_physical_overrides_and_aliases_early(self):
        for selected in ('default', 'override'):
            for kind in ('direct', 'nested', 'runtime-alias', 'prefix-alias', 'physical-alias'):
                with self.subTest(selected=selected, kind=kind), tempfile.TemporaryDirectory(dir=self.root) as folder:
                    base = Path(folder)
                    default = base/'runtimes/battlefield-vietnam/physical-ge7'
                    protected = default if selected == 'default' else base/'custom-physical'
                    physical = base/'other-physical' if selected == 'default' else protected
                    runtime = base/'diagnostic'
                    if kind == 'direct':
                        runtime = protected
                    elif kind == 'nested':
                        runtime = protected/'preserved'
                    elif kind == 'runtime-alias':
                        runtime.symlink_to(protected, target_is_directory=True)
                    elif kind == 'prefix-alias':
                        runtime.mkdir()
                        (runtime/'prefix').symlink_to(protected/'prefix', target_is_directory=True)
                    else:
                        physical = base/'physical-alias'
                        physical.symlink_to(protected, target_is_directory=True)
                        runtime = protected
                    prefix = (runtime/'prefix').resolve()
                    (prefix/'dosdevices').mkdir(parents=True)
                    (prefix/'system.reg').write_text('synthetic registry')
                    drive = prefix/'dosdevices/d:'
                    drive.symlink_to(base/'synthetic-disc')
                    runner = base/'runner'
                    runner.mkdir()
                    called = base/'runner-called'
                    for name in ('wine', 'wineserver'):
                        stub = runner/name
                        stub.write_text('#!/bin/sh\n: > "$CALL_MARKER"\nexit 77\n')
                        stub.chmod(0o755)
                    env = dict(os.environ, RETRO_GAME_RUNTIME_DIR=str(base/'runtimes'),
                               BFV_RUNTIME=str(physical), BFV_FOLDER_RUNTIME=str(runtime),
                               BFV_WINE=str(runner/'wine'), CALL_MARKER=str(called))
                    r = subprocess.run(['bash', str(HERE/'launch_folder.sh')], env=env,
                                       capture_output=True, text=True, timeout=15)
                    self.assertNotEqual(r.returncode, 0)
                    self.assertFalse(called.exists(), 'Wine/server invoked before protection guard')
                    self.assertFalse((runtime/'logs').exists())
                    self.assertFalse((runtime/'.lock').exists())
                    self.assertIn('Refusing physical/preserved prefix', r.stderr)
                    self.assertEqual((prefix/'system.reg').read_text(), 'synthetic registry')
                    self.assertTrue(drive.is_symlink())
                    self.assertEqual(drive.readlink(), base/'synthetic-disc')

    def test_diagnostic_launchers_reject_external_physical_prefix_overlap(self):
        for launcher, variable in (('launch_folder.sh', 'BFV_FOLDER_RUNTIME'),
                                   ('launch_mapped.sh', 'BFV_IMAGE_RUNTIME')):
            for selected in ('default', 'override'):
                for kind in ('shared-prefix', 'prefix-child', 'prefix-parent',
                             'runtime-alias', 'runtime-child', 'runtime-parent',
                             'physical-runtime-parent'):
                    with self.subTest(launcher=launcher, selected=selected, kind=kind), tempfile.TemporaryDirectory(dir=self.root) as folder:
                        base = Path(folder)
                        default = base/'runtimes/battlefield-vietnam/physical-ge7'
                        physical = default if selected == 'default' else base/'custom-physical'
                        physical.mkdir(parents=True)
                        external = base/'external/preserved-prefix'
                        external.mkdir(parents=True)
                        (physical/'prefix').symlink_to(external, target_is_directory=True)
                        runtime = base/'diagnostic'
                        if kind.startswith('prefix-') or kind == 'shared-prefix':
                            runtime.mkdir()
                            target = {'shared-prefix': external, 'prefix-child': external/'child',
                                      'prefix-parent': external.parent}[kind]
                            (runtime/'prefix').symlink_to(target, target_is_directory=True)
                        elif kind == 'runtime-alias':
                            runtime.symlink_to(external, target_is_directory=True)
                        elif kind == 'runtime-child':
                            runtime = external/'child'
                        elif kind == 'runtime-parent':
                            runtime = external.parent
                        else:
                            runtime = physical.parent
                        prefix = (runtime/'prefix').resolve()
                        (prefix/'dosdevices').mkdir(parents=True, exist_ok=True)
                        (prefix/'system.reg').write_text('synthetic registry')
                        drive = prefix/'dosdevices/d:'
                        drive.symlink_to(base/'synthetic-disc')
                        runner = base/'runner'
                        runner.mkdir()
                        called = base/'side-effect-called'
                        # All Wine and media entry points are inert even if the guard fails.
                        for name in ('wine', 'wineserver', 'findmnt', 'losetup'):
                            stub = runner/name
                            stub.write_text('#!/bin/sh\n: > "$CALL_MARKER"\nexit 77\n')
                            stub.chmod(0o755)
                        env = dict(os.environ, RETRO_GAME_RUNTIME_DIR=str(base/'runtimes'),
                                   BFV_RUNTIME=str(base/'other-physical' if selected == 'default' else physical),
                                   BFV_WINE=str(runner/'wine'), BFV_ISO=str(self.iso),
                                   BFV_CD=str(base/'synthetic-disc'), CALL_MARKER=str(called),
                                   PATH=str(runner)+os.pathsep+os.environ['PATH'])
                        env[variable] = str(runtime)
                        r = subprocess.run(['bash', str(HERE/launcher)], env=env,
                                           capture_output=True, text=True, timeout=15)
                        self.assertNotEqual(r.returncode, 0)
                        self.assertFalse(called.exists(), 'Wine/server or media probe preceded guard')
                        self.assertFalse((runtime/'logs').exists())
                        self.assertFalse((runtime/'.lock').exists())
                        self.assertIn('Refusing physical/preserved prefix', r.stderr)
                        self.assertEqual((prefix/'system.reg').read_text(), 'synthetic registry')
                        self.assertEqual(drive.readlink(), base/'synthetic-disc')
                        self.assertEqual((physical/'prefix').readlink(), external)

    def test_nested_joliet_file(self):
        r=self.stage('--file','eReg/Help.txt'); self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual((self.out/'eReg/Help.txt').read_bytes(),self.helpfile)

    def test_rejects_path_traversal(self):
        r=self.stage('--file','../escape'); self.assertNotEqual(r.returncode,0)
        self.assertFalse(self.out.exists())

    def test_wrong_label(self):
        r=self.run_script('stage-disc-cab.py','--device',self.iso,'--label','BFV_1','--cab','sample.cab','--output-dir',self.out)
        self.assertNotEqual(r.returncode,0); self.assertFalse(self.out.exists())

    def test_directory_copy_reverify_and_reject_difference(self):
        def run(n):
            return self.run_script('stage-disc-directory.py','--device',self.iso,'--label','BFV_3','--directory','eReg','--output-dir',self.out,'--manifest',self.root/f'm{n}.json')
        r=run(1); self.assertEqual(r.returncode,0,r.stderr)
        r=run(2); self.assertEqual(r.returncode,0,r.stderr)
        report=json.loads((self.root/'m2.json').read_text()); self.assertEqual(report['verified_files'],1)
        p=self.out/'eReg/Help.txt'; p.write_bytes(b'changed')
        r=run(3); self.assertNotEqual(r.returncode,0); self.assertEqual(p.read_bytes(),b'changed')

    def test_audit_identifies_affected_file(self):
        mp=self.root/'map'; report=self.root/'report.json'
        # Synthetic unread sector includes sample.cab, but not filesystem metadata.
        mp.write_text(f'0 {24*2048} +\n{24*2048} 2048 -\n{25*2048} {7*2048} +\n')
        r=self.run_script('audit-rescue-iso.py',self.iso,mp,report)
        self.assertEqual(r.returncode,0,r.stderr)
        affected=json.loads(report.read_text())['affected_records']
        self.assertEqual(len(affected),2)
        self.assertTrue(all(x['path'].lower()=='/sample.cab' for x in affected))

    def test_launcher_dry_run_no_side_effects(self):
        env=dict(os.environ,BFV_RUNTIME=str(self.root/'runtime'),BFV_WINE='/missing/runner/wine')
        r=subprocess.run(['bash',str(HERE/'launch.sh'),'dry-run'],env=env,capture_output=True,text=True)
        self.assertEqual(r.returncode,0,r.stderr); self.assertFalse((self.root/'runtime').exists())
        r=subprocess.run(['bash',str(HERE/'launch.sh'),'game'],env=env,capture_output=True,text=True)
        self.assertNotEqual(r.returncode,0); self.assertFalse((self.root/'runtime').exists())


if __name__ == '__main__':
    unittest.main()
