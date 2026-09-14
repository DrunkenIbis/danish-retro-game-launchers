#!/usr/bin/env python3
"""Local-only DOSBox-Staging recipe for the supplied Harald archive."""
import argparse
import hashlib
import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
import zipfile

ARCHIVE_SHA = '67ffd957bbd8e76b9c9e918af2c73730d345f3f733b7b89eb8709d091582d006'
FILES = ('HARALD.EXE', 'HARALD.001', 'HARALD.002', 'HARALD.DIR', 'HIGH.DAT')
ZIP_PREFIX = 'Harald Hårdtand/SYSTEM/DOSBOX/GAME/'


def extract(archive, game, expected_sha=ARCHIVE_SHA):
    with Path(archive).open('rb') as src:
        actual = hashlib.file_digest(src, 'sha256').hexdigest()
    if actual != expected_sha:
        raise ValueError(f'Forkert arkiv-SHA256: {actual}; forventede {expected_sha}')
    with zipfile.ZipFile(archive) as z:
        payload = {name: z.read(ZIP_PREFIX + name) for name in FILES}
    if any(not data for data in payload.values()):
        raise ValueError('Arkivet indeholder en tom påkrævet spilfil')
    game = Path(game)
    game.mkdir(parents=True, exist_ok=True)
    for name, data in payload.items():
        target = game / name
        if target.is_symlink():
            raise ValueError(f'Afviser symlink i runtime: {target}')
        if name == 'HIGH.DAT' and target.exists():
            continue
        temporary = target.with_suffix(target.suffix + '.tmp')
        with temporary.open('xb') as dst:
            dst.write(data)
        temporary.replace(target)


def main():
    here = Path(__file__).resolve().parent
    repo = here.parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('install', 'launch'))
    parser.add_argument('--archive', type=Path, help='Den kendte lokale HaraldHaardtand.zip')
    parser.add_argument('--existing', action='store_true', help='Brug lokalt arkiv; ingen download')
    parser.add_argument('--no-launch', action='store_true')
    opts = parser.parse_args()
    source_base = Path(os.environ.get('RETRO_GAME_SOURCE_DIR', repo / 'local/sources'))
    runtime_base = Path(os.environ.get('RETRO_GAME_RUNTIME_DIR', repo / 'local/runtime'))
    source = Path(os.environ.get('HARALD_SOURCE_DIR', source_base / 'harald-haardtand')).expanduser().resolve()
    runtime = Path(os.environ.get('HARALD_RUNTIME_DIR', runtime_base / 'harald-haardtand')).expanduser().resolve()
    game = runtime / 'game'
    cycles = os.environ.get('HARALD_CPU_CYCLES', '6000')
    if not re.fullmatch(r'[0-9]{1,6}', cycles) or not 1000 <= int(cycles) <= 100000:
        raise ValueError('HARALD_CPU_CYCLES skal være et heltal mellem 1000 og 100000')
    if opts.mode == 'install' or any(not (game / name).is_file() for name in FILES):
        archive = opts.archive or (Path(os.environ['HARALD_ARCHIVE']) if 'HARALD_ARCHIVE' in os.environ else None)
        if archive is None:
            archive = source / 'HaraldHaardtand.zip'
            if not archive.exists():
                archive = Path.home() / 'Hentet/HaraldHaardtand.zip'
        archive = archive.expanduser().resolve()
        if not archive.is_file():
            raise ValueError(f'Arkiv mangler: {archive}. Brug install.sh --archive /sti/HaraldHaardtand.zip --no-launch')
        extract(archive, game)
        source.mkdir(parents=True, exist_ok=True)
        cached = source / 'HaraldHaardtand.zip'
        if archive != cached:
            shutil.copy2(archive, cached)
        print(f'Installeret: {game}; eksisterende HIGH.DAT bevaret', flush=True)
    (runtime / 'logs').mkdir(parents=True, exist_ok=True)
    conf = runtime / 'harald-haardtand.conf'
    conf.write_text((here / 'dosbox.conf').read_text().replace('@CYCLES@', cycles))
    if opts.no_launch:
        return
    if os.environ.get('HARALD_DOSBOX_BIN'):
        command = [os.environ['HARALD_DOSBOX_BIN']]
    elif shutil.which('dosbox-staging'):
        command = ['dosbox-staging']
    elif shutil.which('flatpak') and subprocess.run(
            ['flatpak', 'info', 'io.github.dosbox-staging'], stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL).returncode == 0:
        command = ['flatpak', 'run', 'io.github.dosbox-staging']
    else:
        raise ValueError('DOSBox-Staging mangler. Installer io.github.dosbox-staging via Flatpak eller angiv HARALD_DOSBOX_BIN.')
    command += ['-noprimaryconf', '-nolocalconf', '-conf', str(conf)]
    print(f'Runtime: {runtime}', flush=True)
    print(shlex.join(command), flush=True)
    if os.environ.get('HARALD_DRY_RUN') == '1':
        return
    os.environ.setdefault('SDL_AUDIODRIVER', 'pulse')
    os.chdir(runtime)
    os.execvpe(command[0], command, os.environ)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as exc:
        print(f'Harald: {exc}', file=sys.stderr)
        sys.exit(1)
