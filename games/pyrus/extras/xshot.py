#!/usr/bin/env python3
import ctypes, sys
from PIL import Image
libX11=ctypes.CDLL('libX11.so.6')
class XWindowAttributes(ctypes.Structure):
    _fields_=[('x',ctypes.c_int),('y',ctypes.c_int),('width',ctypes.c_int),('height',ctypes.c_int),('border_width',ctypes.c_int),('depth',ctypes.c_int),('visual',ctypes.c_void_p),('root',ctypes.c_ulong),('class_',ctypes.c_int),('bit_gravity',ctypes.c_int),('win_gravity',ctypes.c_int),('backing_store',ctypes.c_int),('backing_planes',ctypes.c_ulong),('backing_pixel',ctypes.c_ulong),('save_under',ctypes.c_int),('colormap',ctypes.c_ulong),('map_installed',ctypes.c_int),('map_state',ctypes.c_int),('all_event_masks',ctypes.c_long),('your_event_mask',ctypes.c_long),('do_not_propagate_mask',ctypes.c_long),('override_redirect',ctypes.c_int),('screen',ctypes.c_void_p)]
class XImage(ctypes.Structure):
    _fields_=[('width',ctypes.c_int),('height',ctypes.c_int),('xoffset',ctypes.c_int),('format',ctypes.c_int),('data',ctypes.c_void_p),('byte_order',ctypes.c_int),('bitmap_unit',ctypes.c_int),('bitmap_bit_order',ctypes.c_int),('bitmap_pad',ctypes.c_int),('depth',ctypes.c_int),('bytes_per_line',ctypes.c_int),('bits_per_pixel',ctypes.c_int),('red_mask',ctypes.c_ulong),('green_mask',ctypes.c_ulong),('blue_mask',ctypes.c_ulong),('obdata',ctypes.c_void_p),('f',ctypes.c_void_p*10)]
libX11.XOpenDisplay.restype=ctypes.c_void_p
libX11.XDefaultRootWindow.argtypes=[ctypes.c_void_p]; libX11.XDefaultRootWindow.restype=ctypes.c_ulong
libX11.XGetWindowAttributes.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.POINTER(XWindowAttributes)]; libX11.XGetWindowAttributes.restype=ctypes.c_int
libX11.XGetImage.argtypes=[ctypes.c_void_p,ctypes.c_ulong,ctypes.c_int,ctypes.c_int,ctypes.c_uint,ctypes.c_uint,ctypes.c_ulong,ctypes.c_int]; libX11.XGetImage.restype=ctypes.POINTER(XImage)
libX11.XDestroyImage.argtypes=[ctypes.POINTER(XImage)]
dpy=libX11.XOpenDisplay(None)
if not dpy: raise SystemExit('no display')
win=int(sys.argv[1],16) if len(sys.argv)>2 else libX11.XDefaultRootWindow(dpy)
out=sys.argv[-1]
attrs=XWindowAttributes(); libX11.XGetWindowAttributes(dpy, win, ctypes.byref(attrs))
w,h=attrs.width,attrs.height
imgp=libX11.XGetImage(dpy, win, 0,0,w,h, 0xffffffff, 2)
img=imgp.contents
buf=ctypes.string_at(img.data, img.bytes_per_line*h)
if img.bits_per_pixel == 32:
    im=Image.frombytes('RGB', (w,h), buf, 'raw', 'BGRX', img.bytes_per_line, 1)
else:
    im=Image.frombytes('RGB', (w,h), buf, 'raw', 'BGR', img.bytes_per_line, 1)
im.save(out)
libX11.XDestroyImage(imgp)
print(out, w,h,img.bits_per_pixel)
