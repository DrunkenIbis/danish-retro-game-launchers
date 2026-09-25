#!/usr/bin/env python3
"""Check ISO9660/Joliet file and metadata extents against a ddrescue map.
This validates read coverage, not file semantics or optical protection fidelity.
"""
import argparse
import json
from pathlib import Path


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('image', type=Path)
    ap.add_argument('mapfile', type=Path)
    ap.add_argument('report', type=Path)
    args = ap.parse_args()
    spans = []
    for line in args.mapfile.read_text().splitlines():
        f = line.split()
        if len(f) != 3 or f[0].startswith('#'):
            continue
        try:
            start, size = int(f[0], 0), int(f[1], 0)
        except ValueError:
            continue
        if f[2] == '+':
            spans.append((start, start+size))
    spans.sort()
    def covered(start, size):
        end = start + size
        pos = start
        for a, b in spans:
            if b <= pos:
                continue
            if a > pos:
                break
            pos = max(pos, b)
            if pos >= end:
                return True
        return size == 0
    records = []
    with args.image.open('rb') as image:
        def read(offset, size):
            if not covered(offset, size):
                raise ValueError(f'Unreadable metadata at {offset}, {size}; cannot audit safely')
            image.seek(offset)
            data = image.read(size)
            if len(data) != size:
                raise ValueError('Short ISO read')
            return data
        roots = []
        for sector in range(16, 80):
            d = read(sector*2048, 2048)
            if d[1:6] != b'CD001':
                raise ValueError('Invalid volume descriptor')
            if d[0] == 255:
                break
            if d[0] == 1:
                roots.append((f'primary-{sector}', 'ascii', d[156:190]))
            if d[0] == 2 and d[88:91] in (b'%/@', b'%/C', b'%/E'):
                roots.append((f'joliet-{sector}', 'utf-16-be', d[156:190]))
            if d[0] in (1, 2):
                size = int.from_bytes(d[132:136], 'little')
                for field, order in ((140, 'little'), (144, 'little'), (148, 'big'), (152, 'big')):
                    lba = int.from_bytes(d[field:field+4], 'little' if order == 'little' else 'big')
                    if lba:
                        records.append({'tree': str(sector), 'path': f'path-table-{field}', 'offset': lba*2048, 'size': size, 'type': 'metadata', 'fully_read': covered(lba*2048, size)})
        def walk(rec, name, tree, encoding, seen):
            offset = int.from_bytes(rec[2:6], 'little')*2048
            size = int.from_bytes(rec[10:14], 'little')
            if rec[25] & 128 or rec[1] or rec[26] or rec[27]:
                raise ValueError('Unsupported multi-extent/interleaved record')
            isdir = bool(rec[25] & 2)
            records.append({'tree': tree, 'path': name, 'offset': offset, 'size': size, 'type': 'directory' if isdir else 'file', 'fully_read': covered(offset, size)})
            if not isdir:
                return
            if (offset, size) in seen:
                raise ValueError('Directory cycle')
            seen = seen | {(offset, size)}
            if size > 16*1024*1024:
                raise ValueError('Oversized directory')
            data = read(offset, size)
            i = 0
            while i < len(data):
                n = data[i]
                if not n:
                    i = (i//2048+1)*2048
                    continue
                r = data[i:i+n]
                i += n
                if len(r) < 34 or 33+r[32] > len(r):
                    raise ValueError('Invalid record')
                raw = r[33:33+r[32]]
                if raw in (b'\0', b'\1'):
                    continue
                child = raw.decode(encoding).split(';')[0]
                walk(r, name.rstrip('/')+'/'+child, tree, encoding, seen)
        for tree, encoding, root in roots:
            walk(root, '/', tree, encoding, set())
    affected = [r for r in records if not r['fully_read']]
    report = {'image': str(args.image), 'trees': [r[0] for r in roots], 'records_checked': len(records), 'affected_records': affected, 'records': records, 'scope': 'ISO9660/Joliet file, directory and path-table read coverage only; not a complete raw-media or protection audit'}
    args.report.write_text(json.dumps(report, indent=2)+'\n')
    print(json.dumps({k: v for k, v in report.items() if k != 'records'}, indent=2))


if __name__ == '__main__':
    main()
