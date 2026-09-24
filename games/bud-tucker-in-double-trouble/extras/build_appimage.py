#!/usr/bin/env python3
"""Private DOSBox package using existing pinned DOS helpers and shared AppImage builder."""
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
from typing import Any

HERE = Path(__file__).resolve().parent
GAME = HERE.parent
REPO = GAME.parents[1]
ID = 'bud-tucker-in-double-trouble'
HELPER = REPO / 'games/gys-paa-regneslottet/extras/build_appimage.py'
spec = importlib.util.spec_from_file_location('dosbox_build_helpers', HELPER)
assert spec is not None and spec.loader is not None
utils: Any = importlib.util.module_from_spec(spec)
spec.loader.exec_module(utils)


def main():
    base = Path(os.environ.get('RETRO_GAME_RUNTIME_DIR', REPO / 'local/runtime')) / ID
    source = Path(os.environ.get('BUD_BUILD_RUNTIME', base / 'folder'))
    build = REPO / 'local/runtime' / ID / 'appimage-build'
    build.mkdir(parents=True, exist_ok=True)
    utils.CACHE = REPO / 'local/cache' / ID
    utils.CACHE.mkdir(parents=True, exist_ok=True)
    for name, sha in [('dosbox-staging-0.83.0.tar.xz', utils.DOSBOX_SHA),
                      ('appimagetool-x86_64.AppImage', utils.TOOL_SHA)]:
        existing = REPO / 'local/cache/gys-paa-regneslottet' / name
        if not (utils.CACHE / name).exists() and existing.is_file() and utils.digest(existing) == sha:
            shutil.copy2(existing, utils.CACHE / name)
    archive = utils.download('dosbox-staging-0.83.0.tar.xz', utils.DOSBOX_URL, utils.DOSBOX_SHA, False)
    tool = utils.download('appimagetool-x86_64.AppImage', utils.TOOL_URL, utils.TOOL_SHA, False)
    with (source / 'session.lock').open('a') as lock, tempfile.TemporaryDirectory(prefix='build-', dir=build) as tmp:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        work = Path(tmp)
        app = work / (ID + '.AppDir')
        app.mkdir()
        for name in ('c/TUCKER/BUD.BAT', 'c/TUCKER/TUCKER.EXE', 'c/G.IN', 'cd-files/TUCKER/INTRO.EXE'):
            if not (source / name).is_file():
                raise RuntimeError('Missing verified runtime file: ' + name)
        with tarfile.open(archive) as tar:
            tar.extractall(work / 'dosbox', filter='data')
        binaries = list((work / 'dosbox').glob('*/dosbox'))
        if len(binaries) != 1:
            raise RuntimeError('Unexpected DOSBox archive layout')
        shutil.copytree(binaries[0].parent, app / 'runtime')
        shutil.copytree(source / 'c', app / 'seed-c')
        shutil.copytree(source / 'cd-files', app / 'cd-files')
        shutil.copy2(HERE / 'AppRun', app / 'AppRun')
        (app / 'AppRun').chmod(0o755)
        (app / 'base.conf').write_text((GAME / 'dosbox.conf.in').read_text().split('[autoexec]')[0])
        (app / 'usr/share/applications').mkdir(parents=True)
        binary = app / 'usr/bin' / ID
        binary.parent.mkdir(parents=True)
        binary.write_text('#!/usr/bin/env bash\nexec "$(cd "$(dirname "$0")/../.." && pwd)/AppRun" "$@"\n')
        binary.chmod(0o755)
        shutil.copy2(GAME / 'README.md', app / 'README.md')
        provenance = {'dosbox_sha256': utils.DOSBOX_SHA, 'appimagetool_sha256': utils.TOOL_SHA,
                      'source_hashes': {str(p.relative_to(REPO)): utils.digest(p) for p in
                                        (HERE / 'AppRun', Path(__file__), GAME / 'dosbox.conf.in', HELPER)},
                      'game_files': {str(p.relative_to(app)): utils.digest(p) for tree in ('seed-c', 'cd-files')
                                     for p in (app / tree).rglob('*') if p.is_file()}}
        (app / 'build-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        output = GAME / 'extras/dist/Bud-Tucker-in-Double-Trouble-x86_64.AppImage'
        output.parent.mkdir(exist_ok=True)
        tool.chmod(0o755)
        # Reuse shared metadata/icon and packer functions, not Wine runtime code.
        env = dict(os.environ, APPDIR=str(app), PROJECT_NAME=ID,
                   DISPLAY_NAME='Bud Tucker in Double Trouble', ARCH='x86_64',
                   CACHE_DIR=str(utils.CACHE), DIST_DIR=str(output.parent),
                   OUTPUT_APPIMAGE=str(output), APPIMAGETOOL_BIN=str(tool), DOWNLOAD_APPIMAGETOOL='0')
        utils.run('bash', '-c', 'source "$1"; wine_appimage_write_desktop_file; wine_appimage_write_icon; wine_appimage_build_appimage',
                  'builder', REPO / 'scripts/wine-appimage-builder.sh', env=env)
        output.with_suffix('.AppImage.sha256').write_text(f'{utils.digest(output)}  {output.name}\n')
        print(output)


if __name__ == '__main__':
    main()
