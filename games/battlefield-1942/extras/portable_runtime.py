"""Private Ubuntu runtime dependency resolver; never installs host packages."""
import re


def closure(packages, roots):
    pending = list(roots)
    selected = set()
    while pending:
        name = pending.pop()
        if name in selected:
            continue
        record = packages[name]
        selected.add(name)
        for field in ('Pre-Depends', 'Depends'):
            for group in record.get(field, '').split(','):
                if not group.strip():
                    continue
                alternatives = [re.split(r'[:\s(]', item.strip())[0] for item in group.split('|')]
                match = next((item for item in alternatives if item in packages), None)
                if match is None:
                    raise ValueError(f'Unresolved dependency of {name}: {group}')
                pending.append(match)
    return sorted(selected)


def runtime_filter(member, destination):
    import posixpath
    import tarfile
    if member.issym() and member.linkname.startswith('/'):
        member = member.replace(linkname=posixpath.relpath(member.linkname.lstrip('/'), posixpath.dirname(member.name)))
    return tarfile.data_filter(member, destination)


def link_wine_data(output):
    """Wine derives data paths from /proc/self/exe, the explicit ELF loader."""
    import os
    from pathlib import Path
    output = Path(output).resolve()
    data = output.parent/'wine/share/wine'
    if not (data/'nls/l_intl.nls').is_file():
        raise ValueError('Bundled Wine NLS data missing')
    for name in ('i386-linux-gnu/ld-linux.so.2', 'x86_64-linux-gnu/ld-linux-x86-64.so.2'):
        loader = (output/'usr/lib'/name).resolve(strict=True)
        loader.relative_to(output)
        link = (loader.parent/'../share').resolve()/'wine'
        link.parent.mkdir(parents=True, exist_ok=True)
        if link.is_symlink():
            link.unlink()
        link.symlink_to(os.path.relpath(data, link.parent))


def build(manifest, cache, output):
    import hashlib
    import json
    from pathlib import Path
    import subprocess
    import tarfile
    import tempfile
    import urllib.request
    cache, output = Path(cache), Path(output)
    cache.mkdir(parents=True, exist_ok=True)
    records = json.loads(Path(manifest).read_text())
    archives = []
    for record in records:
        name = record['filename']
        if Path(name).name != name:
            raise ValueError('Invalid package filename')
        archive = cache/name
        if not archive.exists():
            print('Download', name, flush=True)
            urllib.request.urlretrieve(record['url'], archive)
        if hashlib.sha256(archive.read_bytes()).hexdigest() != record['sha256']:
            raise ValueError('SHA256 mismatch: ' + name)
        archives.append(archive)
    output.mkdir(parents=True, exist_ok=True)
    for archive in archives:
        with tempfile.TemporaryDirectory(dir=cache) as temporary:
            subprocess.run(['7z', 'x', '-y', '-o'+temporary, str(archive), 'data.tar*'], check=True, stdout=subprocess.DEVNULL)
            payload, = Path(temporary).glob('data.tar*')
            with tarfile.open(payload) as tar:
                tar.extractall(output, filter=runtime_filter)
    link_wine_data(output)
    (output/'package-manifest.json').write_text(Path(manifest).read_text())


if __name__ == '__main__':
    import sys
    if len(sys.argv) == 5 and sys.argv[1] == 'build':
        build(*sys.argv[2:])
    else:
        raise SystemExit('usage: portable_runtime.py build MANIFEST CACHE OUTPUT')
