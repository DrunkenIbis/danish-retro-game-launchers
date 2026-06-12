#!/usr/bin/env python3
import ctypes, ctypes.util, os, subprocess, time
from pathlib import Path

WORK = Path('/home/test/lutris_game_scripts_Magnus_Myggen_Leg_og_Laer')
PREFIX = WORK/'wineprefix32'
CD = WORK/'cdrom'
WRAPPER = WORK/'magnus_myggen_leg_og_laer_launch.sh'
OUT = WORK/'screenshots'/'cd_variants'
OUT.mkdir(parents=True, exist_ok=True)

x11 = ctypes.cdll.LoadLibrary(ctypes.util.find_library('X11') or 'libX11.so.6')
xtst = ctypes.cdll.LoadLibrary(ctypes.util.find_library('Xtst') or 'libXtst.so.6')
x11.XOpenDisplay.argtypes=[ctypes.c_char_p]; x11.XOpenDisplay.restype=ctypes.c_void_p
x11.XDefaultRootWindow.argtypes=[ctypes.c_void_p]; x11.XDefaultRootWindow.restype=ctypes.c_ulong
x11.XInternAtom.argtypes=[ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]; x11.XInternAtom.restype=ctypes.c_ulong
x11.XGetWindowProperty.argtypes=[ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_long, ctypes.c_long, ctypes.c_int, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong))]; x11.XGetWindowProperty.restype=ctypes.c_int
x11.XFetchName.argtypes=[ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_char_p)]; x11.XFetchName.restype=ctypes.c_int
x11.XSetInputFocus.argtypes=[ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]; x11.XSetInputFocus.restype=ctypes.c_int
x11.XKeysymToKeycode.argtypes=[ctypes.c_void_p, ctypes.c_ulong]; x11.XKeysymToKeycode.restype=ctypes.c_uint
x11.XFlush.argtypes=[ctypes.c_void_p]
xtst.XTestFakeKeyEvent.argtypes=[ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]; xtst.XTestFakeKeyEvent.restype=ctypes.c_int

def window_ids():
    d=x11.XOpenDisplay(None)
    root=x11.XDefaultRootWindow(d)
    atom=x11.XInternAtom(d,b'_NET_CLIENT_LIST',False)
    at=ctypes.c_ulong(); af=ctypes.c_int(); ni=ctypes.c_ulong(); ba=ctypes.c_ulong(); prop=ctypes.POINTER(ctypes.c_ulong)()
    x11.XGetWindowProperty(d,root,atom,0,4096,False,0,ctypes.byref(at),ctypes.byref(af),ctypes.byref(ni),ctypes.byref(ba),ctypes.byref(prop))
    out=[]
    for i in range(ni.value):
        w=prop[i]
        nm=ctypes.c_char_p(); x11.XFetchName(d,w,ctypes.byref(nm))
        name=(nm.value or b'').decode(errors='replace')
        out.append((w,name,d))
    return out

def find_win(deadline=10):
    end=time.time()+deadline
    while time.time()<end:
        for w,name,d in window_ids():
            if 'MagnusMyggenLegOgLaer' in name:
                return w,d
        time.sleep(.1)
    return None,None

def send_esc(w,d):
    x11.XSetInputFocus(d,w,1,0)
    x11.XFlush(d); time.sleep(.2)
    key=x11.XKeysymToKeycode(d,0xff1b)
    for _ in range(3):
        xtst.XTestFakeKeyEvent(d,key,1,0); x11.XFlush(d); time.sleep(.05)
        xtst.XTestFakeKeyEvent(d,key,0,0); x11.XFlush(d); time.sleep(.35)

def write_ini(value):
    txt=f"[MAGNUS]\nPATH={value}\nPath={value}\nCDDrv={value}\nCDDrive={value}\n"
    for p in [PREFIX/'drive_c/windows/MAGNUS.INI', PREFIX/'drive_c/MAGNUS.INI', CD/'MAGNUS.INI']:
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(txt)

def set_marker(kind):
    m=PREFIX/'dosdevices/d::'
    try: m.unlink()
    except FileNotFoundError: pass
    if kind=='file_cdrom':
        m.write_text('cdrom\n')
    elif kind=='symlink_iso':
        m.symlink_to(WORK/'Magnus-Myggen-Leg-og-Laer.iso')
    elif kind=='symlink_cdrom':
        m.symlink_to(CD)

def run_variant(name, ini, marker):
    write_ini(ini)
    set_marker(marker)
    env=os.environ.copy(); env.update({'MM1_CENTER_WINDOW':'1','WINEDEBUG':'-all'})
    log=OUT/f'{name}.log'
    shot=OUT/f'{name}.png'
    proc=subprocess.Popen(['timeout','18s',str(WRAPPER)], stdout=log.open('w'), stderr=subprocess.STDOUT, env=env)
    w,d=find_win(8)
    if w:
        time.sleep(4)
        send_esc(w,d)
        time.sleep(3)
        subprocess.run(['import','-window',hex(w),str(shot)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        proc.wait(timeout=20)
    except subprocess.TimeoutExpired:
        proc.kill(); proc.wait()
    # Let timeout cleanup happen before next variant.
    time.sleep(1)
    print(name, 'ini=',repr(ini), 'marker=',marker, 'shot=',shot if shot.exists() else 'NO_SHOT', 'exit=',proc.returncode)

variants=[
 ('d_none','D','none'),
 ('dcolon_none','D:','none'),
 ('dslash_none','D:\\','none'),
 ('d_file','D','file_cdrom'),
 ('dcolon_file','D:','file_cdrom'),
 ('d_iso','D','symlink_iso'),
 ('d_cdromlink','D','symlink_cdrom'),
]
for v in variants:
    run_variant(*v)
