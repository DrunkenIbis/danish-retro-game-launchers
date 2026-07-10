#!/usr/bin/env python3
"""Center the legacy Wine game window and clear its EWMH fullscreen state."""

from __future__ import annotations

import ctypes
import ctypes.util
import os
import re
import sys
import time

TITLE_FRAGMENT = sys.argv[1] if len(sys.argv) > 1 else "El Dorado"
SIZE = sys.argv[2] if len(sys.argv) > 2 else "640x480"
match = re.fullmatch(r"(\d+)x(\d+)", SIZE)
if not match:
    raise SystemExit(f"invalid size: {SIZE}")
WANT_WIDTH, WANT_HEIGHT = map(int, match.groups())

lib = ctypes.CDLL(ctypes.util.find_library("X11") or "libX11.so.6")
Display = ctypes.c_void_p
Window = ctypes.c_ulong
Atom = ctypes.c_ulong


class XClientMessageData(ctypes.Union):
    _fields_ = [("l", ctypes.c_long * 5), ("b", ctypes.c_char * 20)]


class XClientMessageEvent(ctypes.Structure):
    _fields_ = [
        ("type", ctypes.c_int),
        ("serial", ctypes.c_ulong),
        ("send_event", ctypes.c_int),
        ("display", Display),
        ("window", Window),
        ("message_type", Atom),
        ("format", ctypes.c_int),
        ("data", XClientMessageData),
    ]


lib.XOpenDisplay.argtypes = [ctypes.c_char_p]
lib.XOpenDisplay.restype = Display
lib.XDefaultRootWindow.argtypes = [Display]
lib.XDefaultRootWindow.restype = Window
lib.XDefaultScreen.argtypes = [Display]
lib.XDefaultScreen.restype = ctypes.c_int
lib.XDisplayWidth.argtypes = [Display, ctypes.c_int]
lib.XDisplayWidth.restype = ctypes.c_int
lib.XDisplayHeight.argtypes = [Display, ctypes.c_int]
lib.XDisplayHeight.restype = ctypes.c_int
lib.XInternAtom.argtypes = [Display, ctypes.c_char_p, ctypes.c_int]
lib.XInternAtom.restype = Atom
lib.XFetchName.argtypes = [Display, Window, ctypes.POINTER(ctypes.c_char_p)]
lib.XFetchName.restype = ctypes.c_int
lib.XQueryTree.argtypes = [Display, Window, ctypes.POINTER(Window), ctypes.POINTER(Window), ctypes.POINTER(ctypes.POINTER(Window)), ctypes.POINTER(ctypes.c_uint)]
lib.XQueryTree.restype = ctypes.c_int
lib.XMoveResizeWindow.argtypes = [Display, Window, ctypes.c_int, ctypes.c_int, ctypes.c_uint, ctypes.c_uint]
lib.XMapRaised.argtypes = [Display, Window]
lib.XSendEvent.argtypes = [Display, Window, ctypes.c_int, ctypes.c_long, ctypes.c_void_p]
lib.XDeleteProperty.argtypes = [Display, Window, Atom]
lib.XFlush.argtypes = [Display]
lib.XFree.argtypes = [ctypes.c_void_p]
lib.XCloseDisplay.argtypes = [Display]


def children(display: Display, window: Window) -> list[Window]:
    root = Window()
    parent = Window()
    nodes = ctypes.POINTER(Window)()
    count = ctypes.c_uint()
    if not lib.XQueryTree(display, window, ctypes.byref(root), ctypes.byref(parent), ctypes.byref(nodes), ctypes.byref(count)):
        return []
    result = [nodes[i] for i in range(count.value)]
    if nodes:
        lib.XFree(nodes)
    return result


def window_name(display: Display, window: Window) -> str:
    raw = ctypes.c_char_p()
    if lib.XFetchName(display, window, ctypes.byref(raw)) and raw.value:
        result = raw.value.decode(errors="replace")
        lib.XFree(raw)
        return result
    return ""


def remove_fullscreen(display: Display, root: Window, window: Window) -> None:
    state = lib.XInternAtom(display, b"_NET_WM_STATE", False)
    fullscreen = lib.XInternAtom(display, b"_NET_WM_STATE_FULLSCREEN", False)
    event = XClientMessageEvent()
    event.type = 33  # ClientMessage
    event.window = window
    event.message_type = state
    event.format = 32
    event.data.l[0] = 0  # _NET_WM_STATE_REMOVE
    event.data.l[1] = fullscreen
    event.data.l[3] = 1  # normal application source
    lib.XSendEvent(display, root, False, (1 << 19) | (1 << 20), ctypes.byref(event))
    lib.XDeleteProperty(display, window, state)


display = lib.XOpenDisplay(os.environ.get("DISPLAY", "").encode() or None)
if not display:
    raise SystemExit(0)

root = lib.XDefaultRootWindow(display)
screen = lib.XDefaultScreen(display)
x = max(0, (lib.XDisplayWidth(display, screen) - WANT_WIDTH) // 2)
y = max(0, (lib.XDisplayHeight(display, screen) - WANT_HEIGHT) // 2)
deadline = time.monotonic() + 12

while time.monotonic() < deadline:
    for window in children(display, root):
        if TITLE_FRAGMENT.lower() in window_name(display, window).lower():
            remove_fullscreen(display, root, window)
            lib.XMoveResizeWindow(display, window, x, y, WANT_WIDTH, WANT_HEIGHT)
            lib.XMapRaised(display, window)
            lib.XFlush(display)
    time.sleep(0.2)

lib.XCloseDisplay(display)
