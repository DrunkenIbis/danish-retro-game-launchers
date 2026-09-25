#!/usr/bin/env python3
"""Read a complete original Joliet directory directly from optical media.
Installation staging only, not a full disc backup. Existing files are verified,
never overwritten. Reads fail rather than substituting bytes on media errors.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
from staging_output import output_directory, regular_stat, open_regular, publish


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--device', default='/dev/sr0')
    ap.add_argument('--label', required=True)
    ap.add_argument('--directory', required=True)
    ap.add_argument('--output-dir', required=True, type=Path)
    ap.add_argument('--manifest', required=True, type=Path)
    args = ap.parse_args()
    parts = args.directory.split('/')
    def safe(name):
        return name not in ('', '.', '..') and '/' not in name and '\\' not in name and '\0' not in name
    if not all(map(safe, parts)):
        ap.error('Expected safe relative directory path')
    fd = os.open(args.device, os.O_RDONLY)
    try:
        def read(offset, size):
            data = os.pread(fd, size, offset)
            if len(data) != size:
                raise OSError('Short optical read')
            return data
        pvd = read(32768, 2048)
        if pvd[:7] != b'\x01CD001\x01' or pvd[40:72].decode('ascii').strip() != args.label:
            raise ValueError('Wrong original medium')
        root = None
        for sector in range(17, 80):
            d = read(sector * 2048, 2048)
            if d[1:6] != b'CD001':
                raise ValueError('Invalid descriptor')
            if d[0] == 255:
                break
            if d[0] == 2 and d[88:91] in (b'%/@', b'%/C', b'%/E'):
                root = d[156:190]
                break
        if root is None:
            raise ValueError('This helper requires a Joliet tree')
        def extent(r):
            if r[25] & 128 or r[1] or r[26] or r[27]:
                raise ValueError('Unsupported multiextent/interleaved record')
            return int.from_bytes(r[2:6], 'little') * 2048, int.from_bytes(r[10:14], 'little')
        def entries(r):
            offset, size = extent(r)
            if not r[25] & 2 or size > 16 * 1024 * 1024:
                raise ValueError('Invalid directory')
            data = read(offset, size)
            i = 0
            result = []
            while i < len(data):
                n = data[i]
                if not n:
                    i = (i // 2048 + 1) * 2048
                    continue
                rec = data[i:i+n]
                if len(rec) < 34 or 33 + rec[32] > len(rec):
                    raise ValueError('Invalid record')
                raw = rec[33:33+rec[32]]
                i += n
                if raw in (b'\0', b'\1'):
                    continue
                name = raw.decode('utf-16-be').split(';')[0]
                if not safe(name):
                    raise ValueError('Unsafe media filename')
                result.append((name, rec))
            if len({n.casefold() for n, _ in result}) != len(result):
                raise ValueError('Ambiguous directory entries')
            return result
        for part in parts:
            hits = [r for n, r in entries(root) if n.casefold() == part.casefold()]
            if len(hits) != 1:
                raise ValueError(f'Missing directory: {part}')
            root = hits[0]
        files = []
        directories = []
        visited = set()
        def walk(r, path):
            key = extent(r)
            if key in visited:
                raise ValueError('Directory cycle')
            visited.add(key)
            directories.append(path)
            for name, rec in entries(r):
                relative = path / name
                if rec[25] & 2:
                    walk(rec, relative)
                else:
                    files.append((relative, *extent(rec)))
        walk(root, Path(*parts))
        print(f'Original directory: {len(files)} files, {len(directories)} directories', flush=True)
        manifest = []
        for relative, offset, size in files:
            with output_directory(args.output_dir, relative.parent) as directory:
                existing = regular_stat(directory, relative.name) is not None
                partial = relative.name + '.partial'
                digest = hashlib.sha256()
                with open_regular(directory, relative.name if existing else partial,
                                  existing=existing, readonly=existing) as out:
                    if existing and os.fstat(out.fileno()).st_size != size:
                        raise ValueError(f'Existing file differs: {relative}')
                    for pos in range(0, size, 1024 * 1024):
                        data = read(offset + pos, min(1024 * 1024, size-pos))
                        digest.update(data)
                        if existing:
                            if out.read(len(data)) != data:
                                raise ValueError(f'Existing file differs: {relative}')
                        else:
                            out.write(data)
                    if not existing:
                        out.flush()
                        os.fsync(out.fileno())
                        out.seek(0)
                        if hashlib.file_digest(out, 'sha256').hexdigest() != digest.hexdigest():
                            raise OSError('Copy hash mismatch')
                        publish(directory, partial, relative.name, out)
            manifest.append({'path': relative.as_posix(), 'size': size, 'sha256': digest.hexdigest(), 'previously_present': existing})
            print('Verified:', relative, size, flush=True)
        for relative in directories:
            with output_directory(args.output_dir, relative):
                pass
        report = {'device': args.device, 'label': args.label, 'directory': args.directory, 'expected_files': len(files), 'verified_files': len(manifest), 'files': manifest, 'full_disc_backup': False}
        with output_directory(args.manifest.parent) as directory:
            with open_regular(directory, args.manifest.name) as out:
                out.write(json.dumps(report, indent=2).encode('utf-8'))
        print(f'COMPLETE: {len(manifest)}/{len(files)} files verified; manifest={args.manifest}', flush=True)
    finally:
        os.close(fd)


if __name__ == '__main__':
    main()
