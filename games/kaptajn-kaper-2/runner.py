#!/usr/bin/env python3
"""Reproducible local DOSBox-Staging launcher for Kaper2.zip."""
import argparse
import fcntl
import hashlib
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import urllib.request
import zipfile

URL = 'https://www.kaptajnkaper.dk/Kaper2.zip'
SHA256 = 'a9cf151351ad6e97f3d8f3bf338829b878df6bdeff6e190fbf3de8bbd7cf8732'
FILES = ('TEMP.PIC', 'TITEL.PIC', 'FIGURES.DAT', 'GO.BAT', 'GRAFTDA2.COM',
         'HLP.DAT', 'KAPER.EXE', 'MAP.PIC', 'REC.DAT', 'SIGTE.PIC')
MUTABLE = {'REC.DAT', 'TEMP.PIC'}


def extract(archive, game, expected_sha=SHA256):
    data = Path(archive).read_bytes()
    if hashlib.sha256(data).hexdigest() != expected_sha:
        raise ValueError('Arkivets SHA256 stemmer ikke med den verificerede download')
    with zipfile.ZipFile(archive) as z:
        payload = {name: z.read(name) for name in FILES}
    if any(not value for value in payload.values()):
        raise ValueError('Tom påkrævet spilfil')
    game = Path(game)
    game.mkdir(parents=True, exist_ok=True)
    for name in FILES:
        if (game / name).is_symlink():
            raise ValueError('Symlink afvist: ' + name)
    for name, value in payload.items():
        target = game / name
        if name in MUTABLE and target.exists():
            continue
        temporary = target.with_suffix(target.suffix + '.tmp')
        with temporary.open('xb') as f:
            f.write(value)
        temporary.replace(target)


def main():
    here = Path(__file__).resolve().parent
    repo = here.parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['install', 'launch'])
    group = parser.add_mutually_exclusive_group()
    group.add_argument('--download', action='store_true')
    group.add_argument('--existing', action='store_true')
    group.add_argument('--archive', type=Path)
    parser.add_argument('--no-launch', action='store_true')
    args = parser.parse_args()
    source = Path(os.environ.get('KAPER_SOURCE_DIR', Path(os.environ.get('RETRO_GAME_SOURCE_DIR', repo / 'local/sources')) / 'kaptajn-kaper-2')).expanduser().resolve()
    runtime = Path(os.environ.get('KAPER_RUNTIME_DIR', Path(os.environ.get('RETRO_GAME_RUNTIME_DIR', repo / 'local/runtime')) / 'kaptajn-kaper-2')).expanduser().resolve()
    runtime.mkdir(parents=True, exist_ok=True)
    lock = (runtime / 'runtime.lock').open('a')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    cycles = os.environ.get('KAPER_CPU_CYCLES', '1000')
    if not re.fullmatch(r'[0-9]{1,5}', cycles) or not 100 <= int(cycles) <= 50000:
        raise ValueError('KAPER_CPU_CYCLES skal være 100–50000')
    game = runtime / 'game'
    if args.mode == 'install' or not all((game / n).is_file() for n in FILES):
        archive = args.archive or Path(os.environ.get('KAPER_ARCHIVE', source / 'Kaper2.zip'))
        archive = archive.expanduser().resolve()
        if args.download:
            source.mkdir(parents=True, exist_ok=True)
            archive = source / 'Kaper2.zip'
            temporary = archive.with_suffix('.download')
            subprocess.run(['curl', '-fL', '--retry', '2', '--max-time', '120', URL, '-o', str(temporary)], check=True)
            data = temporary.read_bytes()
            if hashlib.sha256(data).hexdigest() != SHA256:
                raise ValueError('Download-checksum forkert; eksisterende arkiv bevaret')
            temporary.write_bytes(data)
            temporary.replace(archive)
        if not archive.is_file():
            raise ValueError('Arkiv mangler. Kør install.sh --download --no-launch')
        extract(archive, game)
        print(f'Installeret: {game}; eksisterende REC.DAT/TEMP.PIC bevaret', flush=True)
    conf = runtime / 'kaper.conf'
    conf.write_text((here / 'dosbox.conf').read_text().replace('@CYCLES@', cycles))
    if args.no_launch:
        return
    if os.environ.get('KAPER_DOSBOX_BIN'):
        command = [os.environ['KAPER_DOSBOX_BIN']]
    elif shutil.which('dosbox-staging'):
        command = ['dosbox-staging']
    elif shutil.which('flatpak') and subprocess.run(['flatpak', 'info', 'io.github.dosbox-staging'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
        command = ['flatpak', 'run', '--socket=x11', '--nosocket=wayland', '--env=SDL_VIDEODRIVER=x11', f'--filesystem={runtime}', 'io.github.dosbox-staging']
    else:
        raise ValueError('Installer DOSBox-Staging eller angiv KAPER_DOSBOX_BIN')
    command += ['--noprimaryconf', '--nolocalconf', '--conf', str(conf)]
    print(shlex.join(command), flush=True)
    if os.environ.get('KAPER_DRY_RUN') == '1':
        return
    logs = runtime / 'logs'
    logs.mkdir(exist_ok=True)
    with (logs / 'launch.log').open('w') as log:
        result = subprocess.run(command, cwd=runtime, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        print(f'DOSBox afsluttede med {result.returncode}; se {logs / "launch.log"}', file=sys.stderr)
    sys.exit(result.returncode)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, zipfile.BadZipFile) as exc:
        sys.exit(f'Kaper: {exc}')
