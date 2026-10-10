#!/usr/bin/env python3
"""Build a private Release 3 AppImage with frozen Python and PC-BASIC."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
GAME = HERE.parent
REPO = GAME.parents[1]
ID = 'kaptajn-kaper-source'
NAME = 'kaptajn-kaper-v1-release3-source-x86_64.AppImage'
spec = importlib.util.spec_from_file_location('helpers', REPO / 'games/gys-paa-regneslottet/extras/build_appimage.py')
assert spec is not None and spec.loader is not None
helpers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helpers)
helpers.CACHE = REPO / 'local/cache/gys-paa-regneslottet'


def run(*args, **kwargs):
    subprocess.run([str(x) for x in args], check=True, **kwargs)


def main():
    build = HERE / 'build'
    dist = HERE / 'dist'
    build.mkdir(exist_ok=True)
    dist.mkdir(exist_ok=True)
    tool = helpers.download('appimagetool-x86_64.AppImage', helpers.TOOL_URL, helpers.TOOL_SHA, False)
    with tempfile.TemporaryDirectory(prefix='source-appimage-', dir=build) as tmp:
        work = Path(tmp)
        env = dict(os.environ, KAPER_SOURCE_RUNTIME_DIR=str(work / 'prepared'))
        run('bash', GAME / 'install.sh', '--no-launch', env=env)
        prepared = work / 'prepared'
        python = prepared / 'venv312/bin/python'
        run('uv', 'pip', 'install', '--python', python, 'pyinstaller==6.16.0')
        run(python, '-m', 'PyInstaller', '--noconfirm', '--clean', '--onedir', '--name', 'pcbasic',
            '--collect-all', 'pcbasic', '--collect-all', 'sdl2dll', '--collect-all', 'serial',
            '--distpath', work / 'frozen', '--workpath', work / 'freeze-work', '--specpath', work,
            HERE / 'pcbasic_entry.py', cwd=work)
        app = work / (ID + '.AppDir')
        app.mkdir()
        shutil.copytree(work / 'frozen/pcbasic', app / 'runtime')
        shutil.copytree(prepared / 'game', app / 'game')
        # Include exact original BASIC sources and upstream license alongside the adapted seed.
        upstream = Path(os.environ.get('KAPER_SOURCE_GIT_DIR', REPO / 'local/sources/kaptajn-kaper-source/upstream'))
        manifest = json.loads((prepared / 'source-manifest.json').read_text())
        originals = app / 'upstream-source'
        originals.mkdir()
        for name in manifest['original_sha256']:
            data = subprocess.check_output(['git', '-C', str(upstream), 'show', manifest['commit'] + ':' + name])
            (originals / name).write_bytes(data)
        shutil.copy2(HERE / 'AppRun', app / 'AppRun')
        (app / 'AppRun').chmod(0o755)
        shutil.copy2(GAME / 'README.md', app / 'README.md')
        # Keep the installation recipe and its source adaptation available inside the bundle.
        shutil.copy2(GAME / 'runner.py', app / 'source-recipe.py')
        desktop = f'[Desktop Entry]\nType=Application\nName=Kaptajn Kaper - Version 1 Release 3 (GitHub-kilde)\nX-AppImage-Version=1.3\nExec={ID}\nIcon={ID}\nCategories=Game;\nTerminal=false\n'
        for target in [app / f'{ID}.desktop', app / f'usr/share/applications/{ID}.desktop']:
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(desktop)
        command = app / f'usr/bin/{ID}'
        command.parent.mkdir(parents=True)
        command.write_text('#!/usr/bin/env bash\nexec "$(cd "$(dirname "$0")/../.." && pwd)/AppRun" "$@"\n')
        command.chmod(0o755)
        run('magick', REPO / 'games/kaptajn-kaper-2/extras/icon.svg', app / f'{ID}.png')
        shutil.copy2(app / f'{ID}.png', app / '.DirIcon')
        icon = app / f'usr/share/icons/hicolor/256x256/apps/{ID}.png'
        icon.parent.mkdir(parents=True)
        shutil.copy2(app / f'{ID}.png', icon)
        manifest.update({'packager': 'PyInstaller 6.16.0', 'appimagetool_sha256': helpers.TOOL_SHA,
                         'recipe_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip(),
                         'build_source_sha256': {str(p.relative_to(REPO)): helpers.digest(p) for p in [GAME / 'runner.py', HERE / 'AppRun', HERE / 'pcbasic_entry.py', Path(__file__)]}})
        (app / 'build-provenance.json').write_text(json.dumps(manifest, indent=2) + '\n')
        run(app / 'AppRun', '--version')
        tool.chmod(0o755)
        run(tool, '--appimage-extract', cwd=work, stdout=subprocess.DEVNULL)
        pending = work / NAME
        run(work / 'squashfs-root/AppRun', app, pending, env=dict(os.environ, ARCH='x86_64'))
        output = dist / NAME
        if output.exists():
            backup = dist / (NAME + '.previous-' + helpers.digest(output)[:12])
            if not backup.exists():
                shutil.copy2(output, backup)
        pending.replace(output)
        output.with_suffix('.AppImage.sha256').write_text(f'{helpers.digest(output)}  {NAME}\n')
        print(output)


if __name__ == '__main__':
    main()
