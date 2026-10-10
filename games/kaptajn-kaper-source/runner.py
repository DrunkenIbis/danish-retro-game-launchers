#!/usr/bin/env python3
"""Separate Git-source edition, interpreted by PC-BASIC (no KAPER.EXE)."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

URL = 'https://github.com/kb-dk/KaptajnKaper.git'
COMMIT = '32ee1365f2026748ec2e7079e7395f143026e751'
FILES = ('BUILD.BAS', 'SKUD.BAS', 'TEGN.BAS', 'HLP.BAS', 'SPECIAL.BAS', 'KAPER.BAS', 'TITEL.PIC', 'LICENSE', 'README.md')
GENERATORS = ('BUILD.BAS', 'SKUD.BAS', 'TEGN.BAS', 'HLP.BAS')
GENERATED = ('MAP.PIC', 'SIGTE.PIC', 'FIGURES.DAT', 'HLP.DAT')


def adapt_skud(data):
    old = b'4000 goto 9000'
    if data.count(old) != 1:
        raise ValueError('Unexpected upstream SKUD.BAS line 4000')
    return data.replace(old, b'4000 REM Render ship and reach BSAVE (Linux source recipe)')


def run(*args, **kwargs):
    return subprocess.run([str(x) for x in args], check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=['install', 'launch'])
    parser.add_argument('--no-launch', action='store_true')
    args = parser.parse_args()
    here = Path(__file__).resolve().parent
    repo = here.parents[1]
    source = Path(os.environ.get('KAPER_SOURCE_GIT_DIR', repo / 'local/sources/kaptajn-kaper-source/upstream')).expanduser().resolve()
    runtime = Path(os.environ.get('KAPER_SOURCE_RUNTIME_DIR', repo / 'local/runtime/kaptajn-kaper-source')).expanduser().resolve()
    runtime.mkdir(parents=True, exist_ok=True)
    lock = (runtime / 'recipe.lock').open('a')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    game = runtime / 'game'
    python = runtime / 'venv312/bin/python'
    pcbasic = runtime / 'venv312/bin/pcbasic'
    config = runtime / 'pcbasic.ini'
    config.write_text('[pcbasic]\n')
    common = ['--config=' + str(config), '--codepage=850', '--video=vga', '--syntax=advanced', '--resume=False', '--state=' + str(runtime / 'pcbasic.session')]
    if args.mode == 'install' or not (runtime / 'source-manifest.json').is_file():
        if not shutil.which('uv'):
            raise ValueError('uv mangler; installer uv for at hente isoleret Python 3.12 og PC-BASIC')
        if not source.exists():
            source.parent.mkdir(parents=True, exist_ok=True)
            run('git', 'clone', URL, source)
        # Read immutable objects, never reset or overwrite a developer checkout.
        actual = subprocess.check_output(['git', '-C', str(source), 'rev-parse', COMMIT + '^{commit}'], text=True).strip()
        if actual != COMMIT:
            raise ValueError('Source commit mismatch')
        if not python.exists():
            run('uv', 'venv', '--python', '3.12', runtime / 'venv312')
        run('uv', 'pip', 'install', '--python', python, 'pcbasic==2.0.7', 'pysdl2-dll==2.32.10', 'pyserial==3.5')
        with tempfile.TemporaryDirectory(prefix='prepare-', dir=runtime) as tmp:
            seed = Path(tmp)
            original = {}
            for name in FILES:
                data = subprocess.check_output(['git', '-C', str(source), 'show', COMMIT + ':' + name])
                original[name] = hashlib.sha256(data).hexdigest()
                (seed / name).write_bytes(adapt_skud(data) if name == 'SKUD.BAS' else data)
            logs = runtime / 'logs'
            logs.mkdir(exist_ok=True)
            for name in GENERATORS:
                result = run(pcbasic, name, *common, '--interface=none', '--sound=False', '--quit=True', '--output=STDOUT:', cwd=seed, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=120)
                text = result.stdout.decode('utf-8', errors='replace')
                (logs / (name + '.log')).write_text(text)
                if any(word in text.lower() for word in ['error', 'undefined', 'out of memory', 'overflow', 'illegal']):
                    raise ValueError(f'BASIC generation error in {name}: {text}')
            for name in GENERATED:
                if not (seed / name).is_file() or not (seed / name).stat().st_size:
                    raise ValueError('Generator did not produce ' + name)
            for name in ('MAP.PIC', 'SIGTE.PIC'):
                if (seed / name).stat().st_size != 16392:
                    raise ValueError('Unexpected CGA image size: ' + name)
            game.mkdir(exist_ok=True)
            for name in (*FILES, *GENERATED):
                target = game / name
                if target.is_symlink():
                    raise ValueError('Runtime symlink refused: ' + str(target))
                shutil.copy2(seed / name, target)
            manifest = {'game_version': '1', 'game_release': '3', 'display_version': '1.3', 'repository': URL, 'commit': COMMIT, 'original_sha256': original,
                        'runtime_sha256': {n: hashlib.sha256((game / n).read_bytes()).hexdigest() for n in (*FILES, *GENERATED)},
                        'adaptations': ['SKUD.BAS line 4000: remove jump that skips ship rendering and BSAVE'],
                        'entrypoint': 'SPECIAL.BAS', 'pcbasic': '2.0.7'}
            (runtime / 'source-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        print('Kildeudgave installeret. REC.DAT og TEMP.PIC bevaret.', flush=True)
    if args.no_launch:
        return
    if not pcbasic.is_file() or not all((game / n).is_file() for n in ('SPECIAL.BAS', 'TITEL.PIC', *GENERATED)):
        raise ValueError('Installation incomplete; run install.sh --no-launch')
    # Retain parent-held lock for the entire interpreter lifetime.
    command = [str(pcbasic), 'SPECIAL.BAS', *common, '--interface=graphical', '--sound=True', '--quit=True', '--dimensions=960,720', '--scaling=crisp', '--caption=Kaptajn Kaper - Git-kilde (Version 1 Release 3)']
    env = dict(os.environ)
    env.setdefault('SDL_VIDEODRIVER', 'x11')
    print('Git-kilde: ' + COMMIT + '; SPECIAL.BAS via PC-BASIC', flush=True)
    sys.exit(subprocess.run(command, cwd=game, env=env).returncode)


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, subprocess.SubprocessError) as exc:
        sys.exit('Kaper source: ' + str(exc))
