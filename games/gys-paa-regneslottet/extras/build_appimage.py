#!/usr/bin/env python3
"""Private local bundle, following the sibling Det Magiske Jordbær layout.

No Wine/Flatpak/system DOSBox or Python is required at play time. Host bash,
coreutils, flock, glibc/libstdc++, graphics and audio drivers are still required.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile
import urllib.request

HERE = Path(__file__).resolve().parent
GAME = HERE.parent
REPO = GAME.parents[1]
ID = 'gys-paa-regneslottet'
CACHE = REPO / 'local/cache' / ID
DOSBOX_URL = 'https://github.com/dosbox-staging/dosbox-staging/releases/download/v0.83.0/dosbox-staging-linux-x86_64-v0.83.0.tar.xz'
DOSBOX_SHA = 'd3a94f7f1c3e68a47ec88d61145506c7904452adb0c9c5928cb8cfe2331d6c5c'
TOOL_URL = 'https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage'
# This older AppImageKit tool contains its own type-2 runtime: no runtime download.
TOOL_SHA = 'b90f4a8b18967545fda78a445b27680a1642f1ef9488ced28b65398f2be7add2'


def digest(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def download(name, url, sha, offline):
    target = CACHE / name
    if not target.exists():
        if offline:
            raise RuntimeError(f'Missing offline cache: {target}')
        partial = target.with_suffix('.part')
        try:
            with urllib.request.urlopen(url, timeout=60) as src, partial.open('wb') as dst:
                shutil.copyfileobj(src, dst)
            if digest(partial) != sha:
                raise RuntimeError(f'Checksum mismatch: {url}')
            partial.replace(target)
        finally:
            partial.unlink(missing_ok=True)
    if digest(target) != sha:
        raise RuntimeError(f'Checksum mismatch: {target}')
    return target


def run(*args, **kwargs):
    subprocess.run([str(a) for a in args], check=True, **kwargs)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--appdir-only', action='store_true')
    parser.add_argument('--no-download', action='store_true')
    opts = parser.parse_args()
    for command in ('bash', 'unzip', 'wrestool', 'magick'):
        if not shutil.which(command):
            raise RuntimeError(f'Missing build dependency: {command}')
    CACHE.mkdir(parents=True, exist_ok=True)
    build = HERE / 'build'
    dist = HERE / 'dist'
    build.mkdir(exist_ok=True)
    dist.mkdir(exist_ok=True)
    # All disposable trees live in one new private temporary directory.
    with tempfile.TemporaryDirectory(prefix='gys-', dir=build) as work:
        work = Path(work)
        app = work / f'{ID}.AppDir'
        app.mkdir()
        archive = download('dosbox-staging-0.83.0.tar.xz', DOSBOX_URL, DOSBOX_SHA, opts.no_download)
        with tarfile.open(archive) as tar:
            tar.extractall(work / 'dosbox', filter='data')
        binaries = list((work / 'dosbox').glob('*/dosbox'))
        if len(binaries) != 1:
            raise RuntimeError('Unexpected DOSBox release layout')
        shutil.copytree(binaries[0].parent, app / 'runtime')
        # Reuse the canonical recipe on a fresh private extraction. Do not seed
        # from the user's live runtime or saves and do not open a game window.
        env = {k: v for k, v in os.environ.items() if not k.startswith('GYS_')}
        for key in ('GYS_ARCHIVE', 'GYS_ZIP', 'GYS_SOURCE_DIR'):
            if key in os.environ:
                env[key] = os.environ[key]
        env.update(GYS_RUNTIME_DIR=str(work / 'prepared'), GYS_DOSBOX_BIN='/usr/bin/true')
        run('bash', GAME / 'launch.sh', env=env)
        prepared = work / 'prepared'
        tree = prepared / 'extracted/Gys På Regneslottet/SYSTEM/DOSBOX'
        (app / 'game').mkdir()
        shutil.copytree(tree / 'GAME', app / 'game/GAME')
        shutil.copytree(tree / 'CDROM', app / 'game/CDROM')
        shutil.copy2(prepared / f'{ID}.conf', app / 'game/gys.conf')
        shutil.copy2(HERE / 'AppRun', app / 'AppRun')
        (app / 'AppRun').chmod(0o755)
        desktop = f'[Desktop Entry]\nType=Application\nName=Gys på Regneslottet\nExec={ID}\nIcon={ID}\nCategories=Game;Education;\nTerminal=false\n'
        (app / f'{ID}.desktop').write_text(desktop)
        applications = app / 'usr/share/applications'
        applications.mkdir(parents=True)
        (applications / f'{ID}.desktop').write_text(desktop)
        command = app / 'usr/bin' / ID
        command.parent.mkdir(parents=True)
        command.write_text('#!/usr/bin/env bash\nexec "$(cd "$(dirname "$0")/../.." && pwd)/AppRun" "$@"\n')
        command.chmod(0o755)
        icon = work / 'main.ico'
        run('wrestool', '-x', '-t', '14', '--name', 'MAINICON', '-o', icon,
            app / 'game/GAME/GILISOFT/GYS_CD/WNEWADDD.EXE')
        for size in (32, 48, 64, 128, 256):
            target = app / f'usr/share/icons/hicolor/{size}x{size}/apps/{ID}.png'
            target.parent.mkdir(parents=True)
            run('magick', str(icon) + '[0]', '-filter', 'point', '-resize', f'{size}x{size}', target)
        shutil.copy2(app / f'usr/share/icons/hicolor/256x256/apps/{ID}.png', app / f'{ID}.png')
        shutil.copy2(app / f'{ID}.png', app / '.DirIcon')
        shutil.copy2(GAME / 'README.md', app / 'game/README.md')
        provenance = {'dosbox_version': '0.83.0', 'dosbox_url': DOSBOX_URL,
                      'dosbox_sha256': DOSBOX_SHA, 'appimagetool_url': TOOL_URL,
                      'appimagetool_sha256': TOOL_SHA,
                      'config_sha256': digest(app / 'game/gys.conf'),
                      'recipe_commit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True).strip()}
        (app / 'build-provenance.json').write_text(json.dumps(provenance, indent=2) + '\n')
        run(app / 'runtime/dosbox', '-noprimaryconf', '-nolocalconf', '--version')
        output = dist / f'{ID}-x86_64.AppImage'
        if not opts.appdir_only:
            tool = download('appimagetool-x86_64.AppImage', TOOL_URL, TOOL_SHA, opts.no_download)
            tool.chmod(0o755)
            run(tool, '--appimage-extract', cwd=work, stdout=subprocess.DEVNULL)
            pending = work / output.name
            run(work / 'squashfs-root/AppRun', app, pending, env=dict(os.environ, ARCH='x86_64'))
            pending.replace(output)
            output.with_suffix('.AppImage.sha256').write_text(f'{digest(output)}  {output.name}\n')
            print(f'AppImage: {output}', flush=True)
        # Keep a inspectable AppDir without deleting arbitrary caller paths.
        final = build / f'{ID}.AppDir'
        if final.exists():
            shutil.rmtree(final)
        app.rename(final)
        print(f'AppDir: {final}', flush=True)


if __name__ == '__main__':
    main()
