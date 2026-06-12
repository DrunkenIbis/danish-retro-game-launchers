#!/usr/bin/env python3
import ctypes, sys, time
libX11=ctypes.CDLL('libX11.so.6')
libXtst=ctypes.CDLL('libXtst.so.6')
libX11.XOpenDisplay.restype=ctypes.c_void_p
libX11.XSetInputFocus.argtypes=[ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_ulong]
libX11.XWarpPointer.argtypes=[ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_int, ctypes.c_int, ctypes.c_uint, ctypes.c_uint, ctypes.c_int, ctypes.c_int]
libXtst.XTestFakeButtonEvent.argtypes=[ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
libX11.XFlush.argtypes=[ctypes.c_void_p]
if len(sys.argv) != 4:
    raise SystemExit('usage: xclick_window.py <hex-window-id> <x> <y>')
dpy=libX11.XOpenDisplay(None)
if not dpy: raise SystemExit('no display')
win=int(sys.argv[1],16); x=int(sys.argv[2]); y=int(sys.argv[3])
libX11.XSetInputFocus(dpy, ctypes.c_ulong(win), 1, 0); libX11.XFlush(dpy); time.sleep(0.2)
libX11.XWarpPointer(dpy, 0, ctypes.c_ulong(win), 0,0,0,0, x,y); libX11.XFlush(dpy); time.sleep(0.2)
libXtst.XTestFakeButtonEvent(dpy, 1, 1, 0); libX11.XFlush(dpy); time.sleep(0.08)
libXtst.XTestFakeButtonEvent(dpy, 1, 0, 0); libX11.XFlush(dpy); time.sleep(0.3)
