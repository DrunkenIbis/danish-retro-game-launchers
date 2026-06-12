#!/usr/bin/env python3
import ctypes, sys, subprocess
lib=ctypes.CDLL('libX11.so.6')
class Attr(ctypes.Structure):
    _fields_=[('x',ctypes.c_int),('y',ctypes.c_int),('width',ctypes.c_int),('height',ctypes.c_int),('border_width',ctypes.c_int),('depth',ctypes.c_int),('visual',ctypes.c_void_p),('root',ctypes.c_ulong),('class_',ctypes.c_int),('bit_gravity',ctypes.c_int),('win_gravity',ctypes.c_int),('backing_store',ctypes.c_int),('backing_planes',ctypes.c_ulong),('backing_pixel',ctypes.c_ulong),('save_under',ctypes.c_int),('colormap',ctypes.c_ulong),('map_installed',ctypes.c_int),('map_state',ctypes.c_int),('all_event_masks',ctypes.c_long),('your_event_mask',ctypes.c_long),('do_not_propagate_mask',ctypes.c_long),('override_redirect',ctypes.c_int),('screen',ctypes.c_void_p)]
lib.XOpenDisplay.restype=ctypes.c_void_p
lib.XQueryTree.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.POINTER(ctypes.c_ulong),ctypes.POINTER(ctypes.c_ulong),ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong)),ctypes.POINTER(ctypes.c_uint)]
lib.XGetWindowAttributes.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.POINTER(Attr)]
d=lib.XOpenDisplay(None)
root=ctypes.c_ulong(); parent=ctypes.c_ulong(); children=ctypes.POINTER(ctypes.c_ulong)(); n=ctypes.c_uint()
start=int(sys.argv[1],16)
def props(w):
    try:
        return subprocess.check_output(['xprop','-id',hex(w),'WM_NAME','WM_CLASS','_NET_WM_PID'], text=True, stderr=subprocess.DEVNULL).replace('\n',' | ')
    except Exception: return ''
def walk(w,depth=0):
    a=Attr(); lib.XGetWindowAttributes(d,w,ctypes.byref(a))
    print('  '*depth+f'{hex(w)} x={a.x} y={a.y} w={a.width} h={a.height} map={a.map_state} '+props(w))
    rr=ctypes.c_ulong(); pp=ctypes.c_ulong(); cc=ctypes.POINTER(ctypes.c_ulong)(); nn=ctypes.c_uint()
    if lib.XQueryTree(d,w,ctypes.byref(rr),ctypes.byref(pp),ctypes.byref(cc),ctypes.byref(nn)):
        for i in range(nn.value): walk(cc[i],depth+1)
walk(start)
