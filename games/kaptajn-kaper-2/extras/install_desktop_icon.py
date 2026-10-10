#!/usr/bin/env python3
"""Install this private AppImage's icon and desktop shortcut for the current user."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent
ID = 'kaptajn-kaper-2'


def main():
    artifact = HERE / 'dist' / 'kaptajn-kaper-v1-release5-dos-x86_64.AppImage'
    if not artifact.is_file():
        raise SystemExit(f'Missing AppImage: {artifact}')
    data = Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))
    icon = data / f'icons/hicolor/256x256/apps/{ID}.png'
    icon.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='kaper-icon-') as tmp:
        subprocess.run([str(artifact), '--appimage-extract', f'{ID}.png'], cwd=tmp, check=True)
        shutil.copy2(Path(tmp) / 'squashfs-root' / f'{ID}.png', icon)
    # GVfs metadata controls the raw file icon in GNOME Files/Desktop Icons.
    subprocess.run(['gio', 'set', str(artifact), 'metadata::custom-icon', icon.as_uri()], check=True)
    desktop = Path(subprocess.check_output(['xdg-user-dir', 'DESKTOP'], text=True).strip())
    desktop.mkdir(parents=True, exist_ok=True)
    escaped = str(artifact).replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%')
    entry = (f'[Desktop Entry]\nType=Application\nName=Kaptajn Kaper - Version 1 Release 5 (DOS)\n'
             f'Exec="{escaped}"\nIcon={icon}\nTerminal=false\nCategories=Game;\n')
    for target in (data / f'applications/{ID}.desktop', desktop / f'{ID}.desktop'):
        target.parent.mkdir(parents=True, exist_ok=True)
        if target.exists() and target.read_text() != entry:
            raise SystemExit(f'Refusing to overwrite a different shortcut: {target}')
        target.write_text(entry)
        target.chmod(0o755)
        subprocess.run(['desktop-file-validate', str(target)], check=True)
    shortcut = desktop / f'{ID}.desktop'
    subprocess.run(['gio', 'set', str(shortcut), 'metadata::trusted', 'true'], check=True)
    print(f'Icon: {icon}\nDesktop shortcut: {shortcut}')


if __name__ == '__main__':
    main()
