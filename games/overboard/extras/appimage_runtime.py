#!/usr/bin/env python3
"""Private Overboard bundle. Requires host CDEmu/VHBA; never uses physical CD."""
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import time


def empty_device(status):
    for line in status.splitlines():
        fields = line.split()
        if len(fields) >= 2 and fields[0].isdigit() and fields[1] == 'False':
            return fields[0]
    return None


def relocate_toc(text, binary):
    if any(c in binary for c in ('"', '\n', '\r')):
        raise ValueError('Unsupported character in media path')
    return re.sub(r'(?m)^((?:DATAFILE|FILE)\s+)"[^"]+"',
                  lambda m: m[1] + '"' + binary + '"', text)


def run(args, **kwargs):
    return subprocess.run(args, check=True, text=True, capture_output=True, **kwargs).stdout


def main():
    app = Path(__file__).resolve().parent.parent
    state = Path(os.environ.get('OVERBOARD_APPIMAGE_STATE', str(Path(os.environ.get('XDG_DATA_HOME', str(Path.home()/'.local/share')))/'overboard-appimage'))).absolute()
    wine = app/'wine/bin/wine'
    server = wine.parent/'wineserver'
    display_mode = os.environ.get('OVERBOARD_DISPLAY_MODE', 'windowed16')
    if display_mode not in ('windowed16', 'classic'):
        raise RuntimeError('OVERBOARD_DISPLAY_MODE skal være windowed16 eller classic')
    tools = ['cdemu', 'udisksctl', 'findmnt', 'cp']
    if display_mode == 'windowed16':
        tools.append('gamescope')
        if not (app/'usr/bin/Xephyr').is_file():
            raise RuntimeError('Bundlet Xephyr mangler')
    for tool in tools:
        if not shutil.which(tool):
            raise RuntimeError('Mangler værtskommando: ' + tool)
    if not Path('/sys/module/vhba').exists():
        raise RuntimeError('VHBA mangler for den aktive kernel. Installér CDEmu/VHBA på værten.')
    if not wine.is_file():
        raise RuntimeError('Bundlet Wine mangler')
    status = run(['cdemu', 'status'])
    if '--check' in sys.argv:
        print('OK: CDEmu/VHBA og bundlet Wine. State: ' + str(state))
        return
    state.mkdir(parents=True, exist_ok=True)
    lock = (state/'.lock').open('w')
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    prefix = state/'prefix'
    if not (prefix/'system.reg').exists():
        staging = state/'prefix.partial'
        if staging.exists():
            shutil.rmtree(staging)
        staging.mkdir()
        run(['cp', '-a', str(app/'game/prefix')+'/.', str(staging)])
        staging.rename(prefix)
    binary = state/'OVERBOARD.bin'
    src = app/'game/OVERBOARD.bin'
    if not binary.exists() or binary.stat().st_size != src.stat().st_size:
        tmp = state/'OVERBOARD.bin.partial'
        shutil.copyfile(src, tmp)
        tmp.replace(binary)
    toc = state/'OVERBOARD.toc'
    toc.write_text(relocate_toc((app/'game/OVERBOARD.toc').read_text(), str(binary)))
    exe = prefix/'drive_c/Program Files/Psygnosis/Overboard!/Ob.exe'
    if not exe.is_file():
        raise RuntimeError('Installeret Ob.exe mangler')
    for entry in (prefix/'dosdevices').iterdir():
        if entry.is_symlink() and ':' in entry.name and entry.name != 'c:':
            entry.unlink()
    device_id = empty_device(status)
    if device_id is None:
        run(['cdemu', 'add-device'])
        device_id = empty_device(run(['cdemu', 'status']))
    if device_id is None:
        raise RuntimeError('Intet ledigt CDEmu-drev; andre spil berøres ikke')
    env = os.environ.copy()
    for key in ('WINEARCH', 'WINEDLLOVERRIDES', 'WINEDLLPATH', 'WINEPREFIX', 'WINE_BIN', 'LD_LIBRARY_PATH'):
        env.pop(key, None)
    env.update(WINEPREFIX=str(prefix), WINEDEBUG=os.environ.get('OVERBOARD_WINEDEBUG', '-all'))
    loaded = False
    device = None
    def interrupted(signum, frame):
        raise KeyboardInterrupt()
    signal.signal(signal.SIGTERM, interrupted)
    try:
        run(['cdemu', 'load', device_id, str(toc)])
        loaded = True
        for line in run(['cdemu', 'device-mapping']).splitlines():
            fields = line.split()
            if len(fields) >= 3 and fields[0] == device_id:
                device = fields[1]
        if not device:
            raise RuntimeError('CDEmu gav intet virtuelt blokdrev')
        mount = None
        for _ in range(30):
            p = subprocess.run(['findmnt', '--json', '-S', device, '-o', 'TARGET'], text=True, capture_output=True)
            rows = json.loads(p.stdout or '{}').get('filesystems', [])
            if rows:
                mount = Path(rows[0]['target'])
                break
            subprocess.run(['udisksctl', 'mount', '-b', device], capture_output=True)
            time.sleep(0.5)
        if mount is None or not (mount/'ob.exe').is_file():
            raise RuntimeError('Virtuel Overboard-cd kunne ikke monteres')
        (prefix/'dosdevices/d:').symlink_to(mount)
        (prefix/'dosdevices/d::').symlink_to(device)
        for args in [ ['reg', 'add', r'HKCU\Software\Wine\Drives', '/v', 'd:', '/d', 'cdrom', '/f'],
                      ['reg', 'add', r'HKCU\Software\Wine', '/v', 'Version', '/d', 'win98', '/f'] ]:
            run([str(wine)] + args, env=env)
        print(f'Bundled Wine: {wine}\nState: {state}\nCDEmu: {device_id} {device}\nDisplay: {display_mode}', flush=True)
        if display_mode == 'windowed16':
            # Registry helpers started Wine on the host X server; stop that server
            # before switching this prefix into Xephyr's 16-bit display.
            subprocess.run([str(server), '-k'], env=env, capture_output=True)
            # -k returns 1 when registry helpers already let the server exit.
            subprocess.run([str(server), '-w'], env=env, check=True, timeout=20)
            command = [sys.executable, str(app/'game/display_runner.py')]
        else:
            command = [str(wine), 'explorer', '/desktop=Overboard,800x600', r'C:\Program Files\Psygnosis\Overboard!\Ob.exe']
        with (state/'game.log').open('w') as log:
            result = subprocess.run(command, env=env, cwd=prefix/'drive_c', stdout=log, stderr=subprocess.STDOUT)
            subprocess.run([str(server), '-w'], env=env)
            if result.returncode:
                raise RuntimeError(f'Wine afsluttede med kode {result.returncode}; se {state}/game.log')
    finally:
        if loaded:
            subprocess.run([str(server), '-k'], env=env, capture_output=True)
            try:
                subprocess.run([str(server), '-w'], env=env, timeout=20, capture_output=True)
            finally:
                if device:
                    subprocess.run(['udisksctl', 'unmount', '-b', device], capture_output=True)
                subprocess.run(['cdemu', 'unload', device_id], capture_output=True)
                for name in ('d:', 'd::'):
                    (prefix/'dosdevices'/name).unlink(missing_ok=True)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as exc:
        message = 'Overboard AppImage: ' + str(exc)
        print(message, file=sys.stderr)
        if shutil.which('zenity'):
            subprocess.run(['zenity', '--error', '--text', message])
        sys.exit(1)
