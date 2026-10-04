#!/usr/bin/env python3
"""Experimental cdrdao single-BIN CDDA extraction, not a portable launcher.

Uses owner-supplied media only. Ogg Vorbis encoding is lossy. Never overwrites
existing tracks. cdrdao raw BIN CDDA uses signed 16-bit big-endian samples.
"""
import argparse
from pathlib import Path
import re
import subprocess


def frames(value):
    if value == '0':
        return 0
    minute, second, frame = map(int, value.split(':'))
    if minute < 0 or not 0 <= second < 60 or not 0 <= frame < 75:
        raise ValueError('Invalid CD frame time')
    return (minute * 60 + second) * 75 + frame


def disc_positions(text):
    """Return absolute INDEX 01 CD frames, retaining data and stored pregaps."""
    cursor = 150  # Red Book lead-in offset
    positions = []
    for block in re.split(r'(?m)^TRACK ', text)[1:]:
        start = re.search(r'^START (\S+)$', block, re.M)
        silence = re.search(r'^SILENCE (\S+)$', block, re.M)
        data = re.search(r'^DATAFILE "[^"\n]+" (\S+)', block, re.M)
        audio = re.search(r'^FILE "[^"\n]+" #\d+ \S+ (\S+)$', block, re.M)
        if not data and not audio:
            raise ValueError('Unsupported TOC track extent')
        positions.append(cursor + (frames(start[1]) if start else 0))
        cursor += frames((data or audio)[1]) + (frames(silence[1]) if silence else 0)
    if not positions:
        raise ValueError('No tracks')
    return positions


def audio_ranges(text):
    ranges = []
    blocks = re.split(r'(?m)^TRACK ', text)[1:]
    for number, block in enumerate(blocks, 1):
        if not block.startswith('AUDIO\n'):
            continue
        match = re.search(r'^FILE "[^"\n]+" #(\d+) (\S+) (\S+)$', block, re.M)
        if not match:
            raise ValueError('Expected single-BIN cdrdao FILE with byte offset')
        base, offset, length = match.groups()
        start = re.search(r'^START (\S+)$', block, re.M)
        silence = re.search(r'^SILENCE (\S+)$', block, re.M)
        skip = (frames(start[1]) if start else 0) - (frames(silence[1]) if silence else 0)
        if skip < 0 or skip >= frames(length):
            raise ValueError('Unsupported pregap')
        ranges.append((number, int(base) + (frames(offset) + skip) * 2352,
                       (frames(length) - skip) * 2352))
    if not ranges:
        raise ValueError('No audio tracks')
    return ranges


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('toc', type=Path)
    parser.add_argument('bin', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    ranges = audio_ranges(args.toc.read_text())
    size = args.bin.stat().st_size
    if any(offset + length > size for _, offset, length in ranges):
        raise ValueError('Track extends beyond BIN')
    args.output.mkdir(parents=True, exist_ok=True)
    with args.bin.open('rb') as source:
        for number, offset, length in ranges:
            out = args.output / f'Track{number:02d}.ogg'
            if out.exists():
                raise FileExistsError(out)
            source.seek(offset)
            subprocess.run(['ffmpeg', '-nostdin', '-v', 'error', '-n', '-f', 's16be',
                            '-ar', '44100', '-ac', '2', '-i', 'pipe:0',
                            '-c:a', 'libvorbis', '-q:a', '6', str(out)],
                           input=source.read(length), check=True)
            print(number, offset, length, out, flush=True)


if __name__ == '__main__':
    main()
