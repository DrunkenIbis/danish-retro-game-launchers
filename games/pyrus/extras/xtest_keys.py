#!/usr/bin/env python3
import ctypes, sys, time, subprocess, re
libX11=ctypes.CDLL('libX11.so.6')
libXtst=ctypes.CDLL('libXtst.so.6')
libX11.XOpenDisplay.restype=ctypes.c_void_p
libX11.XKeysymToKeycode.argtypes=[ctypes.c_void_p, ctypes.c_ulong]
libX11.XKeysymToKeycode.restype=ctypes.c_uint
libX11.XSetInputFocus.argtypes=[ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
libXtst.XTestFakeKeyEvent.argtypes=[ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
libXtst.XTestFakeButtonEvent.argtypes=[ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
libX11.XFlush.argtypes=[ctypes.c_void_p]
KEYSYMS={
 'Return':0xff0d, 'Enter':0xff0d, 'Tab':0xff09, 'Escape':0xff1b, 'space':0x20,
 'Alt_L':0xffe9, 'Left':0xff51, 'Right':0xff53, 'Up':0xff52, 'Down':0xff54,
}
def get_win():
    if len(sys.argv)>1 and sys.argv[1].startswith('0x'): return int(sys.argv.pop(1),16)
    out=subprocess.check_output(['xprop','-root','_NET_CLIENT_LIST'], text=True, stderr=subprocess.DEVNULL)
    ids=re.findall(r'0x[0-9a-fA-F]+', out)
    return int(ids[-1],16)
def key(dpy, name):
    code=libX11.XKeysymToKeycode(dpy, KEYSYMS.get(name, ord(name) if len(name)==1 else 0))
    libXtst.XTestFakeKeyEvent(dpy, code, 1, 0); libX11.XFlush(dpy); time.sleep(0.05)
    libXtst.XTestFakeKeyEvent(dpy, code, 0, 0); libX11.XFlush(dpy); time.sleep(0.15)
def main():
    dpy=libX11.XOpenDisplay(None)
    if not dpy: raise SystemExit('no display')
    win=get_win()
    libX11.XSetInputFocus(dpy, ctypes.c_ulong(win), 1, 0); libX11.XFlush(dpy); time.sleep(0.2)
    seq=sys.argv[1:] or ['Return']
    for name in seq: key(dpy, name)
if __name__=='__main__': main()
