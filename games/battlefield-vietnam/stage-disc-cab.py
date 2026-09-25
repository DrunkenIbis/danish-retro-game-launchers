#!/usr/bin/env python3
"""Stage an original ISO9660 file from physical media, not a disc backup.
Avoids stale Linux ISO9660 dentries after installer-held disc swaps.
No error recovery/zero filling: a read error aborts and leaves .partial.
"""
import argparse
import hashlib
import os
from pathlib import Path
from staging_output import output_directory, regular_stat, open_regular, publish


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--device', default='/dev/sr0')
    ap.add_argument('--label', required=True)
    choice = ap.add_mutually_exclusive_group(required=True)
    choice.add_argument('--cab', help='Root cabinet basename (legacy option)')
    choice.add_argument('--file', help='Relative ISO9660 file path, preserving output hierarchy')
    ap.add_argument('--output-dir', required=True, type=Path)
    ap.add_argument('--resume', action='store_true', help='Verify partial bytes against this disc before resuming')
    args = ap.parse_args()
    if args.cab and (Path(args.cab).name != args.cab or not args.cab.lower().endswith('.cab')):
        ap.error('Expected a CAB basename')
    requested = args.cab or args.file
    parts = requested.split('/')
    if any(part in ('', '.', '..') or '\\' in part for part in parts):
        ap.error('Expected a safe relative path using forward slashes')
    fd = os.open(args.device, os.O_RDONLY)
    try:
        def read_exact(offset, length):
            data = os.pread(fd, length, offset)
            if len(data) != length:
                raise OSError('Short optical read; no data was substituted')
            return data
        pvd = read_exact(16 * 2048, 2048)
        if pvd[:7] != b'\x01CD001\x01':
            raise ValueError('Not a primary ISO9660 descriptor')
        label = pvd[40:72].decode('ascii').strip()
        if label != args.label:
            raise ValueError(f'Wrong disc: {label}, expected {args.label}')
        # Prefer the on-disc Joliet tree for original Windows long filenames.
        # Keep the primary volume label as the medium identity check.
        current = pvd[156:190]
        encoding = 'ascii'
        for sector in range(17, 80):
            descriptor = read_exact(sector * 2048, 2048)
            if descriptor[1:6] != b'CD001':
                raise ValueError('Invalid volume descriptor')
            if descriptor[0] == 255:
                break
            if descriptor[0] == 2 and descriptor[88:91] in (b'%/@', b'%/C', b'%/E'):
                current = descriptor[156:190]
                encoding = 'utf-16-be'
                break
        for depth, part in enumerate(parts):
            extent = int.from_bytes(current[2:6], 'little')
            size = int.from_bytes(current[10:14], 'little')
            if size > 16 * 1024 * 1024:
                raise ValueError('Unexpected directory size')
            directory = read_exact(extent * 2048, size)
            matches = []
            names = []
            i = 0
            while i < len(directory):
                n = directory[i]
                if not n:
                    i = (i // 2048 + 1) * 2048
                    continue
                record = directory[i:i+n]
                if len(record) < 34:
                    raise ValueError('Invalid directory record')
                raw_name = record[33:33+record[32]]
                if raw_name in (b'\x00', b'\x01'):
                    i += n
                    continue
                name = raw_name.decode(encoding).split(';')[0]
                names.append(name)
                if name.casefold() == part.casefold():
                    if record[25] & 128 or record[1] or record[26] or record[27]:
                        raise ValueError('Unsupported multiextent/interleaved entry')
                    matches.append(record)
                i += n
            if len(matches) != 1:
                raise ValueError(f'No unique {part} found; entries={names!r}')
            current = matches[0]
            if bool(current[25] & 2) != (depth < len(parts)-1):
                raise ValueError('Unexpected file/directory type')
        offset = int.from_bytes(current[2:6], 'little')
        length = int.from_bytes(current[10:14], 'little')
        target = args.output_dir.joinpath(*parts)
        with output_directory(args.output_dir, Path(*parts[:-1])) as directory:
            partial = target.name + '.partial'
            existing = regular_stat(directory, partial) is not None
            if regular_stat(directory, target.name) is not None or (existing and not args.resume):
                raise FileExistsError('Preserving existing output; choose a fresh output directory')
            digest = hashlib.sha256()
            # Existence, not byte length, selects resume mode (including empty files).
            with open_regular(directory, partial, existing=existing) as out:
                start = os.fstat(out.fileno()).st_size
                if start > length:
                    raise ValueError('Partial file exceeds original length')
                if existing:
                    print(f'Checking {start} existing bytes against {label}', flush=True)
                    for pos in range(0, start, 1024 * 1024):
                        data = read_exact(offset * 2048 + pos, min(1024 * 1024, start-pos))
                        if out.read(len(data)) != data:
                            raise ValueError('Partial copy does not match original disc; preserved unchanged')
                        digest.update(data)
                print(f'Copying bytes {start}..{length}', flush=True)
                out.seek(start)
                for pos in range(start, length, 1024 * 1024):
                    data = read_exact(offset * 2048 + pos, min(1024 * 1024, length-pos))
                    out.write(data)
                    digest.update(data)
                out.flush()
                os.fsync(out.fileno())
                # Verify through the same no-follow descriptor before publication.
                out.seek(0)
                if hashlib.file_digest(out, 'sha256').hexdigest() != digest.hexdigest():
                    raise OSError('Copy verification failed')
                publish(directory, partial, target.name, out)
        print(f'Original disc: {args.device} label={label}', flush=True)
        print(f'Verified file: {target} bytes={length} sha256={digest.hexdigest()}', flush=True)
        print('Installation staging only; NOT a full or archival disc backup.', flush=True)
    finally:
        os.close(fd)


if __name__ == '__main__':
    main()
