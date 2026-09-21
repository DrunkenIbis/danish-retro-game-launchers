#!/usr/bin/env python3
"""Private Q112DK bundle; CDEmu/VHBA and compatible Wine libraries are host dependencies."""

import fcntl
import hashlib
import json
import os
from pathlib import Path
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


def run(args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, text=True,
                          capture_output=True, **kwargs).stdout


def launch(app, state):
    state.mkdir(parents=True, exist_ok=True)
    with (state/'.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        prefix = state/'prefix'
        if not (prefix/'system.reg').is_file():
            staging = state/'prefix.partial'
            if staging.exists():
                shutil.rmtree(staging)
            staging.mkdir()
            run(['cp', '-a', str(app/'game/prefix')+'/.', staging])
            staging.rename(prefix)
        image = state/'Q112DK.iso'
        source = app/'game/Q112DK.iso'
        source_digest = hashlib.sha256(source.read_bytes()).digest()
        if not image.exists() or hashlib.sha256(image.read_bytes()).digest() != source_digest:
            temporary = state/'Q112DK.iso.partial'
            shutil.copyfile(source, temporary)
            if hashlib.sha256(temporary.read_bytes()).digest() != source_digest:
                raise RuntimeError('ISO-kopien kunne ikke verificeres.')
            temporary.replace(image)
        dos = prefix/'dosdevices'
        for entry in dos.iterdir():
            if entry.is_symlink() and ':' in entry.name and entry.name != 'c:':
                entry.unlink()
        wine = app/'wine/bin/wine'
        server = wine.parent/'wineserver'
        env = os.environ.copy()
        for key in ('WINEDLLPATH', 'WINE_BIN', 'LD_LIBRARY_PATH', 'WINELOADER', 'WINESERVER'):
            env.pop(key, None)
        env.update(WINEPREFIX=str(prefix), WINEARCH='win32',
                   WINEDEBUG='-all', WINEDLLOVERRIDES='mscoree,mshtml=')
        device_id = empty_device(run(['cdemu', 'status']))
        if device_id is None:
            run(['cdemu', 'add-device'])
            device_id = empty_device(run(['cdemu', 'status']))
        if device_id is None:
            raise RuntimeError('Intet ledigt CDEmu-drev; eksisterende medier røres ikke.')
        loaded = False
        device = None
        try:
            run(['cdemu', 'load', device_id, image])
            loaded = True
            # add-device/load can return before udev creates the node and ACL.
            # Re-read only our selected mapping; never substitute another drive.
            deadline = time.monotonic() + 15.0
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise RuntimeError('CDEmu returnerede intet læsbart virtuelt blokdrev inden 15 sekunder.')
                mapping = run(['cdemu', 'device-mapping'], timeout=remaining)
                device = None
                for line in mapping.splitlines():
                    fields = line.split()
                    if len(fields) >= 3 and fields[0] == device_id:
                        device = fields[1]
                if device and Path(device).is_block_device() and os.access(device, os.R_OK):
                    break
                time.sleep(min(0.5, max(0.0, deadline - time.monotonic())))
            mount = None
            for attempt in range(30):
                result = subprocess.run(['findmnt', '--json', '-S', device, '-o', 'SOURCE,TARGET,LABEL'], text=True, capture_output=True)
                rows = json.loads(result.stdout or '{}').get('filesystems', [])
                if rows:
                    if len(rows) != 1 or Path(rows[0].get('source', '')).resolve() != Path(device).resolve() or rows[0].get('label') != 'Q112DK':
                        raise RuntimeError('Q112DK mount-readback matcher ikke det virtuelle drev.')
                    mount = Path(rows[0]['target'])
                    if not mount.is_dir():
                        raise RuntimeError('Q112DK mountpoint mangler.')
                    break
                subprocess.run(['udisksctl', 'mount', '-b', device], capture_output=True)
                time.sleep(0.5)
            if mount is None:
                raise RuntimeError('CDEmu-mediet kunne ikke monteres.')
            (dos/'d:').symlink_to(mount)
            (dos/'d::').symlink_to(device)
            run([wine, 'reg', 'add', r'HKCU\Software\Wine\Drives', '/v', 'd:', '/d', 'cdrom', '/f'], env=env)
            # Wine's first helper can discover host optical drives; remove them again.
            for entry in dos.iterdir():
                if entry.is_symlink() and ':' in entry.name and entry.name not in ('c:', 'd:', 'd::'):
                    entry.unlink()
            if (dos/'d:').resolve() != mount.resolve() or (dos/'d::').resolve() != Path(device).resolve():
                raise RuntimeError('Wine D:-mapping ændrede sig før spilstart.')
            print(f'Bundled Wine: {wine}\nState: {state}\nCDEmu: {device_id} {device}\nMount: {mount}', flush=True)
            with (state/'game.log').open('w') as log:
                result = subprocess.run([str(wine), 'explorer', '/desktop=Quizkampen,800x600',
                                         r'C:\Program Files\Magnus & Myggen - Quizkampen\mm12main.EXE'],
                                        env=env, cwd=prefix/'drive_c/Program Files/Magnus & Myggen - Quizkampen',
                                        stdout=log, stderr=subprocess.STDOUT)
                run([server, '-w'], env=env)
                if result.returncode:
                    raise RuntimeError(f'Wine afsluttede med kode {result.returncode}; se {state}/game.log')
        finally:
            if loaded:
                subprocess.run([str(server), '-k'], env=env, capture_output=True)
                run([server, '-w'], env=env, timeout=20)
                # Never unload a different image if another client changed the drive.
                owned = False
                for line in run(['cdemu', 'status']).splitlines():
                    fields = line.split(None, 2)
                    if len(fields) == 3 and fields[:2] == [device_id, 'True']:
                        owned = Path(fields[2]).resolve() == image.resolve()
                if owned:
                    if device:
                        subprocess.run(['udisksctl', 'unmount', '-b', device], capture_output=True)
                    run(['cdemu', 'unload', device_id])
                for name in ('d:', 'd::'):
                    (dos/name).unlink(missing_ok=True)


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if argv not in ([], ['--check']):
        raise RuntimeError('Brug uden argumenter eller --check (ingen spilstart).')
    for tool in ('cdemu', 'udisksctl', 'findmnt', 'cp'):
        if not shutil.which(tool):
            raise RuntimeError('Mangler værtskommando: '+tool)
    if not Path('/sys/module/vhba').exists():
        raise RuntimeError('CDEmu kræver indlæst VHBA til den aktive kernel.')
    app = Path(__file__).resolve().parent.parent
    for relative in ('wine/bin/wine', 'wine/bin/wineserver', 'game/prefix/system.reg', 'game/Q112DK.iso'):
        if not (app/relative).is_file():
            raise RuntimeError('Bundlet fil mangler: '+relative)
    state = Path(os.environ.get('MMQ_Q112DK_STATE', str(Path(os.environ.get('XDG_DATA_HOME', str(Path.home()/'.local/share')))/'quizkampen-q112dk-appimage'))).absolute()
    status = run(['cdemu', 'status'])
    if argv == ['--check']:
        print('OK: bundlet Wine-GE/prefix/ISO; CDEmu/VHBA tilgængelig.\nState: '+str(state)+'\n'+status)
        print('Et ledigt virtuelt drev tilføjes ved start, hvis alle drev er optaget.')
        return
    def interrupted(signum, frame):
        raise KeyboardInterrupt()
    signal.signal(signal.SIGTERM, interrupted)
    launch(app, state)


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        sys.exit(130)
    except Exception as exc:
        print('Quizkampen Q112DK AppImage: '+str(exc), file=sys.stderr)
        sys.exit(1)
