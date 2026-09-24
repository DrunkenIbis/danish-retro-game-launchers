#!/usr/bin/env python3
"""Archive the verified single-track Mode 1 BUD_USA disc, read-only."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--device', default='/dev/sr0')
p.add_argument('--output', required=True, type=Path)
a = p.parse_args()
label = subprocess.check_output(['lsblk', '-dn', '-o', 'LABEL', a.device], text=True).strip()
if label != 'BUD_USA':
    raise SystemExit('Wrong disc: expected BUD_USA, got ' + label)
a.output.parent.mkdir(parents=True, exist_ok=True)
partial = a.output.with_suffix('.iso.partial')
report = a.output.with_suffix('.backup.json')
if any(x.exists() for x in (a.output, partial, report)):
    raise SystemExit('Refusing to overwrite an existing backup, partial read, or report')
fd = os.open(a.device, os.O_RDONLY | os.O_NONBLOCK)
metadata = {'device': os.path.realpath(a.device), 'label': label,
            'format': 'ISO, 2048-byte Mode 1 user-data sectors; not raw subchannel archival',
            'complete': False, 'read_errors': [], 'bytes': 0}
try:
    header = bytearray(2)
    fcntl.ioctl(fd, 0x5305, header, True)  # CDROMREADTOCHDR
    tracks = []
    for track in list(range(header[0], header[1] + 1)) + [0xAA]:
        entry = bytearray(12)
        entry[0], entry[2] = track, 1  # CDROM_LBA
        fcntl.ioctl(fd, 0x5306, entry, True)
        tracks.append({'track': track, 'control': entry[1] >> 4,
                       'lba': struct.unpack_from('=i', entry, 4)[0]})
    metadata['toc'] = tracks
    if len(tracks) != 2 or tracks[0]['lba'] != 0 or not tracks[0]['control'] & 4:
        raise RuntimeError('Not a single data track starting at LBA 0; ISO backup refused')
    sectors = tracks[-1]['lba']
    digest = hashlib.sha256()
    with partial.open('xb') as out:
        for start in range(0, sectors, 512):
            wanted = min(512, sectors - start) * 2048
            data = os.pread(fd, wanted, start * 2048)
            if len(data) != wanted:
                raise OSError(f'Short read at LBA {start}: {len(data)}/{wanted}')
            out.write(data)
            digest.update(data)
            metadata['bytes'] += len(data)
        out.flush()
        os.fsync(out.fileno())
    metadata['sha256'] = digest.hexdigest()
    # Independent read-back of the completed local file.
    with partial.open('rb') as saved:
        if hashlib.file_digest(saved, 'sha256').hexdigest() != metadata['sha256']:
            raise RuntimeError('Backup read-back checksum mismatch')
    partial.rename(a.output)
    metadata['complete'] = True
except Exception as exc:
    metadata['read_errors'].append(str(exc))
    raise
finally:
    os.close(fd)
    report.write_text(json.dumps(metadata, indent=2) + '\n')
    print(json.dumps(metadata, indent=2), flush=True)
