#!/usr/bin/env python3
"""Private DOS bundle. Reuses the sibling Gys pinned download/build utilities."""
import argparse
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

HERE = Path(__file__).resolve().parent
GAME = HERE.parent
REPO = GAME.parents[1]
ID = 'harald-haardtand'
HELPER = REPO / 'games/gys-paa-regneslottet/extras/build_appimage.py'
spec = importlib.util.spec_from_file_location('dosbox_build_helpers', HELPER)
assert spec is not None and spec.loader is not None
utils = importlib.util.module_from_spec(spec)
spec.loader.exec_module(utils)
utils.CACHE = REPO / 'local/cache' / ID


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--no-download', action='store_true')
    opts = parser.parse_args()
    utils.CACHE.mkdir(parents=True, exist_ok=True)
    build = HERE / 'build'
    dist = HERE / 'dist'
    build.mkdir(exist_ok=True)
    dist.mkdir(exist_ok=True)
    # Reuse an already verified local cache, but validate every copied byte again.
    for name, sha in [('dosbox-staging-0.83.0.tar.xz', utils.DOSBOX_SHA),
                      ('appimagetool-x86_64.AppImage', utils.TOOL_SHA)]:
        existing = REPO / 'local/cache/gys-paa-regneslottet' / name
        if not (utils.CACHE / name).exists() and existing.is_file() and utils.digest(existing) == sha:
            shutil.copy2(existing, utils.CACHE / name)
    archive = utils.download('dosbox-staging-0.83.0.tar.xz', utils.DOSBOX_URL, utils.DOSBOX_SHA, opts.no_download)
    tool = utils.download('appimagetool-x86_64.AppImage', utils.TOOL_URL, utils.TOOL_SHA, opts.no_download)
    with tempfile.TemporaryDirectory(prefix='harald-', dir=build) as tmp:
        work = Path(tmp)
        app = work / (ID + '.AppDir')
        app.mkdir()
        with tarfile.open(archive) as tar:
            tar.extractall(work / 'dosbox', filter='data')
        binaries = list((work / 'dosbox').glob('*/dosbox'))
        if len(binaries) != 1:
            raise RuntimeError('Unexpected DOSBox tarball layout')
        shutil.copytree(binaries[0].parent, app / 'runtime')
        env = {k: v for k, v in os.environ.items() if not k.startswith('HARALD_')}
        for key in ('HARALD_ARCHIVE', 'HARALD_SOURCE_DIR'):
            if key in os.environ:
                env[key] = os.environ[key]
        env['HARALD_RUNTIME_DIR'] = str(work / 'prepared')
        utils.run('bash', GAME / 'install.sh', '--existing', '--no-launch', env=env)
        shutil.copytree(work / 'prepared/game', app / 'game')
        shutil.copy2(work / 'prepared/harald-haardtand.conf', app / 'harald.conf')
        shutil.copy2(HERE / 'AppRun', app / 'AppRun')
        (app / 'AppRun').chmod(0o755)
        desktop = f'[Desktop Entry]\nType=Application\nName=Harald Hårdtand\nExec={ID}\nIcon={ID}\nCategories=Game;\nTerminal=false\n'
        for target in (app / f'{ID}.desktop', app / f'usr/share/applications/{ID}.desktop'):
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(desktop)
        command = app / f'usr/bin/{ID}'
        command.parent.mkdir(parents=True)
        command.write_text('#!/usr/bin/env bash\nexec "$(cd "$(dirname "$0")/../.." && pwd)/AppRun" "$@"\n')
        command.chmod(0o755)
        utils.run('magick', HERE / 'icon.svg', app / f'{ID}.png')
        shutil.copy2(app / f'{ID}.png', app / '.DirIcon')
        icon = app / f'usr/share/icons/hicolor/256x256/apps/{ID}.png'
        icon.parent.mkdir(parents=True)
        shutil.copy2(app / f'{ID}.png', icon)
        shutil.copy2(GAME / 'README.md', app / 'README.md')
        files = [GAME / 'runner.py', GAME / 'dosbox.conf', HERE / 'AppRun', HERE / 'build_appimage.py', HELPER]
        provenance = {'dosbox_sha256': utils.DOSBOX_SHA, 'appimagetool_sha256': utils.TOOL_SHA,
                      'recipe_commit': subprocess.check_output(['git','rev-parse','HEAD'], cwd=REPO, text=True).strip(),
                      'source_hashes': {str(p.relative_to(REPO)): utils.digest(p) for p in files},
                      'game_hashes': {p.name: utils.digest(p) for p in (app / 'game').iterdir()}}
        (app / 'build-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        tool.chmod(0o755)
        utils.run(tool, '--appimage-extract', cwd=work, stdout=subprocess.DEVNULL)
        pending = work / f'{ID}-x86_64.AppImage'
        utils.run(work / 'squashfs-root/AppRun', app, pending, env=dict(os.environ, ARCH='x86_64'))
        output = dist / pending.name
        pending.replace(output)
        output.with_suffix('.AppImage.sha256').write_text(f'{utils.digest(output)}  {output.name}\n')
        print(output)


if __name__ == '__main__':
    main()
