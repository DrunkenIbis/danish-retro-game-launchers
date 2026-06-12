#!/usr/bin/env python3
import ctypes, sys, time
libX11=ctypes.CDLL('libX11.so.6')
libXtst=ctypes.CDLL('libXtst.so.6')
libX11.XOpenDisplay.restype=ctypes.c_void_p
libX11.XDefaultRootWindow.argtypes=[ctypes.c_void_p]
libX11.XDefaultRootWindow.restype=ctypes.c_ulong
libX11.XWarpPointer.argtypes=[ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_int, ctypes.c_int, ctypes.c_uint, ctypes.c_uint, ctypes.c_int, ctypes.c_int]
libXtst.XTestFakeButtonEvent.argtypes=[ctypes.c_void_p, ctypes.c_uint, ctypes.c_int, ctypes.c_ulong]
libX11.XFlush.argtypes=[ctypes.c_void_p]
dpy=libX11.XOpenDisplay(None)
if not dpy: raise SystemExit('no display')
root=libX11.XDefaultRootWindow(dpy)
x=int(sys.argv[1]); y=int(sys.argv[2])
libX11.XWarpPointer(dpy, 0, root, 0,0,0,0, x,y); libX11.XFlush(dpy); time.sleep(0.2)
libXtst.XTestFakeButtonEvent(dpy, 1, 1, 0); libX11.XFlush(dpy); time.sleep(0.05)
libXtst.XTestFakeButtonEvent(dpy, 1, 0, 0); libX11.XFlush(dpy); time.sleep(0.2)
