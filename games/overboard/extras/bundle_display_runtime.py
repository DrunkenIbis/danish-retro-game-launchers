#!/usr/bin/env python3
"""Bundle the build host's display runtime with provenance, without host installs.
Private artifact: this is packaging from a confirmed seed, not an installer recipe.
"""
from pathlib import Path
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys


def elf_dependencies(source):
    result = subprocess.run(['ldd', str(source)], capture_output=True, text=True)
    if result.returncode or 'not found' in result.stdout or 'not found' in result.stderr:
        raise ValueError(f'ldd failed for {source} (exit {result.returncode}): '
                         + result.stdout + result.stderr)
    return [path for line in result.stdout.splitlines()
            for path in re.findall(r'(?:=>\s+|^\s*)(/[^\s]+)', line)]


def assemble(app):
    app = Path(app).resolve()
    root = app/'display'
    lib = root/'lib'
    lib.mkdir(parents=True)
    manifest = {}
    visited = set()

    def copy_file(src, dest):
        src, dest = Path(src), Path(dest)
        dest.parent.mkdir(parents=True, exist_ok=True)
        digest = hashlib.sha256(src.read_bytes()).hexdigest()
        if dest.exists():
            if hashlib.sha256(dest.read_bytes()).hexdigest() != digest:
                raise ValueError('Dependency collision: '+str(dest))
        else:
            shutil.copy2(src, dest)
        manifest[str(dest.relative_to(app))] = {'source':str(src), 'sha256':digest}

    def elf(src, dest=None):
        src = Path(src)
        dest = dest or lib/src.name
        copy_file(src, dest)
        real = src.resolve()
        if real in visited:
            return
        visited.add(real)
        for path in elf_dependencies(src):
            elf(path)

    for name in ('python3.14','Xephyr','Xwayland','xkbcomp','gamescope','gamescopereaper'):
        source = str(Path('/usr/bin')/name) if name == 'python3.14' else shutil.which(name)
        if not source:
            raise ValueError('Missing '+name)
        elf(source, root/'bin'/name)
    elf('/lib64/ld-linux-x86-64.so.2')
    # Dynamic loads not represented by the executable DT_NEEDED closure.
    for pattern in ('libGLX_mesa.so*','libEGL_mesa.so*','libvulkan_*.so','libgallium*.so*'):
        for source in Path('/usr/lib64').glob(pattern):
            elf(source)
    for source in Path('/usr/lib64/dri').glob('*.so'):
        elf(source, root/'dri'/source.name)
    plugin = Path('/usr/lib64/libdecor/plugins-1/libdecor-cairo.so')
    if plugin.exists():
        elf(plugin, root/'libdecor'/plugin.name)
    for source in Path('/usr/lib64/python3.14/lib-dynload').glob('*.so'):
        elf(source, root/'lib/python3.14/lib-dynload'/source.name)
    for base in (Path('/usr/lib64/python3.14'), Path('/usr/lib/python3.14')):
        if base.is_dir():
            shutil.copytree(base, root/'lib/python3.14', dirs_exist_ok=True,
                            ignore=shutil.ignore_patterns('site-packages','__pycache__','test','tests'))
    for source in (Path('/usr/share/X11/xkb'),Path('/usr/share/gamescope')):
        if source.exists():
            shutil.copytree(source,root/'share'/source.relative_to('/usr/share'),dirs_exist_ok=True)
    for source in Path('/usr/share/vulkan/icd.d').glob('*.json'):
        data=json.loads(source.read_text())
        library=Path(data['ICD']['library_path'])
        if not library.is_absolute():
            library=Path('/usr/lib64')/library.name
        if library.exists() and library.read_bytes()[:5] == b'\x7fELF\x02':
            elf(library)
            data['ICD']['library_path']='../../../lib/'+library.name
            target=root/'share/vulkan/icd.d'/source.name
            target.parent.mkdir(parents=True,exist_ok=True)
            target.write_text(json.dumps(data,indent=2))
    # Include runtime package license notices and NEVRA provenance.
    packages=set()
    for source in visited:
        result=subprocess.run(['rpm','-qf','--qf','%{NAME}\n',str(source)],capture_output=True,text=True)
        if result.returncode==0:
            packages.update(result.stdout.splitlines())
    for name in sorted(packages):
        source=Path('/usr/share/licenses')/name
        if source.exists():
            shutil.copytree(source,root/'licenses'/name,dirs_exist_ok=True)
    provenance=subprocess.run(['rpm','-q',*sorted(packages)],capture_output=True,text=True,check=True).stdout
    (root/'rpm-packages.txt').write_text(provenance)
    (root/'file-manifest.json').write_text(json.dumps(manifest,indent=2))
    print('Bundled ELF files:',len(visited),flush=True)


if __name__=='__main__':
    assemble(sys.argv[1])
