#!/usr/bin/env python3
"""Private kernel-free Overboard package; no CD mounts or host installs."""
import fcntl
import os
from pathlib import Path
import shutil
import sys


def sanitize_prefix(prefix):
    """Sanitize only the staged copy; never follow a user's home links."""
    prefix = Path(prefix).resolve()
    folders = {'Desktop', 'Documents', 'My Documents', 'Downloads', 'Music',
               'My Music', 'Pictures', 'My Pictures', 'Videos', 'My Videos'}
    users = prefix/'drive_c/users'
    # walk() does not descend into directory symlinks (including user roots).
    for base, dirs, files in os.walk(prefix, followlinks=False):
        base = Path(base)
        for name in dirs + files:
            path = base/name
            parts = path.relative_to(prefix).parts
            nested_templates = (len(parts) == 8 and parts[:2] == ('drive_c', 'users')
                                and parts[3:] == ('AppData', 'Roaming', 'Microsoft', 'Windows', 'Templates'))
            if path.is_symlink() and ((base.parent == users and name in folders) or nested_templates):
                path.unlink()
                path.mkdir()
    drives = prefix/'dosdevices'
    if drives.is_dir() and not drives.is_symlink():
        for path in drives.iterdir():
            if path.is_symlink() and path.name != 'c:':
                path.unlink()
    for base, dirs, files in os.walk(prefix, followlinks=False):
        for name in dirs + files:
            path = Path(base)/name
            if path.is_symlink():
                try:
                    path.resolve().relative_to(prefix)
                except (ValueError, RuntimeError, OSError) as exc:
                    raise ValueError('Escaping prefix link: '+str(path.relative_to(prefix))) from exc


def display_args(env):
    return ['--inner'] if env.get('OVERBOARD_DISPLAY') == 'direct' or not env.get('WAYLAND_DISPLAY') else []


def check(app):
    required = ['wine/bin/wine', 'wine/bin/wineserver',
                'portable/usr/lib/i386-linux-gnu/ld-linux.so.2',
                'portable/usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2',
                'display/lib/ld-linux-x86-64.so.2', 'display/bin/Xephyr',
                'display/bin/gamescope', 'display/bin/Xwayland',
                'game/prefix/system.reg',
                'game/prefix/drive_c/Program Files/Psygnosis/Overboard!/winmm.dll',
                'game/prefix/drive_c/Program Files/Psygnosis/Overboard!/winmm.ini',
                'game/prefix/drive_c/Program Files/Psygnosis/Overboard!/Music/Track02.ogg']
    return ['Missing '+p for p in required if not (app/p).is_file()]


def main():
    app = Path(__file__).resolve().parent.parent
    problems = check(app)
    if problems:
        print('\n'.join(problems), file=sys.stderr)
        return 1
    if '--check' in sys.argv:
        print('Payload present. Graphics/audio/gameplay require a real launch.')
        return 0
    state = Path(os.environ.get('OVERBOARD_STATE', str(Path(os.environ.get('XDG_DATA_HOME', str(Path.home()/'.local/share')))/'overboard-kernel-free-portable'))).absolute()
    state.mkdir(parents=True, exist_ok=True)
    with (state/'launch.lock').open('w') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:
            print('Overboard already running in this state directory.', file=sys.stderr)
            return 1
        prefix = state/'prefix'
        if not prefix.exists():
            staging = state/'prefix.copying'
            if staging.exists():
                raise RuntimeError('Incomplete seed copy; preserve/rename prefix.copying before retrying.')
            print('Preparing private writable prefix...', flush=True)
            shutil.copytree(app/'game/prefix', staging, symlinks=True)
            staging.rename(prefix)
        env = os.environ.copy()
        env.update(WINEPREFIX=str(prefix), WINEDLLOVERRIDES='winmm=n,b',
                   OVERBOARD_WINE=str(app/'portable/bin/wine'),
                   OVERBOARD_XEPHYR=str(app/'usr/bin/Xephyr'),
                   OVERBOARD_PYTHON=str(app/'usr/bin/python3'),
                   OVERBOARD_GLAMOR='1', OVERBOARD_COPY_FRAMES='0',
                   OVERBOARD_GAMESCOPE_BACKEND='wayland')
        args = display_args(env)
        if args:
            print('Direct X11 mode: aspect-preserving maximized scaling requires a Wayland desktop.', flush=True)
        from display_runner import supervised_call
        return supervised_call([str(app/'usr/bin/python3'), str(app/'game/display_runner.py'), *args], env=env)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as exc:
        print('Overboard: '+str(exc), file=sys.stderr)
        sys.exit(1)
