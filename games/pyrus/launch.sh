#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO="${PYRUS_ISO:-$HERE/Pyrus.iso}"
CDROM="${PYRUS_CDROM:-$HERE/cdrom}"
PREFIX="${WINEPREFIX:-$HERE/wineprefix32}"
WINEBIN="${PYRUS_WINE:-$(command -v wine32 || command -v wine)}"
MODE="${PYRUS_MODE:-pyrus}"
DESKTOP="${PYRUS_DESKTOP:-Pyrus,640x480}"
CENTER_WINDOW="${PYRUS_CENTER_WINDOW:-1}"
case "$MODE" in
  pyrus) CMD='cd /d D:\ && Pyrus.exe' ;;
  loader) CMD='cd /d D:\ && Loader.exe' ;;
  paint) CMD='cd /d D:\\Paint && Paint.exe' ;;
  puzzle) CMD='cd /d D:\\Puzzle && Puzzle.exe' ;;
  quiz) CMD='cd /d C:\\Pyrus\\Quiz && Quiz.exe' ;;
  viewer) CMD='cd /d D:\\Viewer && PyrusView.exe' ;;
  setup) CMD='cd /d D:\\ && Setup.exe' ;;
  *) CMD="$MODE" ;;
esac

if [[ "${PYRUS_DRY_RUN:-0}" == "1" ]]; then
  printf 'HERE=%s\nISO=%s\nCDROM=%s\nPREFIX=%s\nWINEBIN=%s\nMODE=%s\nCMD=%s\nDESKTOP=%s\n' "$HERE" "$ISO" "$CDROM" "$PREFIX" "$WINEBIN" "$MODE" "$CMD" "$DESKTOP"
  exit 0
fi
[[ -f "$ISO" ]] || { echo "Missing ISO: $ISO" >&2; exit 2; }
if [[ ! -f "$CDROM/Loader.exe" || ! -f "$CDROM/Pyrus.exe" ]]; then
  mkdir -p "$CDROM"
  7z x -y -o"$CDROM" "$ISO" >/dev/null
fi
# Wine hangs on the old Cinepak intro movie; skipping only the intro reaches the actual game menu.
if [[ "${PYRUS_SKIP_INTRO:-1}" == "1" && -f "$CDROM/Data/intro.avi" ]]; then
  mv -f "$CDROM/Data/intro.avi" "$CDROM/Data/intro.avi.disabled"
fi
printf 'PYRUS\n' > "$CDROM/.windows-label"
mkdir -p "$(dirname "$PREFIX")"
export WINEPREFIX="$PREFIX"
if [[ ! -d "$PREFIX/drive_c/windows" ]]; then
  export WINEARCH="${WINEARCH:-win32}"
fi
mkdir -p "$PREFIX/dosdevices"
ln -sfn "$CDROM" "$PREFIX/dosdevices/d:"
ln -sfn "$CDROM/.windows-label" "$PREFIX/dosdevices/d::"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-}"
export WINEDEBUG="${WINEDEBUG:--all}"
# The Pyrus menu decides whether the dice/Quiz component is installed from the
# Windows uninstall registry key.  The old Win16 Quiz installer writes a literal
# %SystemDrive% path under Wine, so self-heal the real installed copy and marker
# so clicking the red dice starts Quiz.exe instead of Setup.exe forever.
QUIZ_INSTALL_DIR="$PREFIX/drive_c/Pyrus/Quiz"
if [[ "${PYRUS_FIX_QUIZ_INSTALL:-1}" == "1" ]]; then
  if [[ ! -f "$QUIZ_INSTALL_DIR/Quiz.exe" ]]; then
    mkdir -p "$(dirname "$QUIZ_INSTALL_DIR")"
    cp -a "$CDROM/Quiz" "$QUIZ_INSTALL_DIR"
  fi
  "$WINEBIN" reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Quiz' /v InstallPath /t REG_SZ /d 'C:\Pyrus\Quiz' /f >/dev/null 2>&1 || true
  "$WINEBIN" reg add 'HKCU\Software\Microsoft\Windows\CurrentVersion\Uninstall\Quiz' /v DisplayName /t REG_SZ /d 'Quiz' /f >/dev/null 2>&1 || true
  "$WINEBIN" reg add 'HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Quiz' /v InstallPath /t REG_SZ /d 'C:\Pyrus\Quiz' /f >/dev/null 2>&1 || true
  "$WINEBIN" reg add 'HKLM\Software\Microsoft\Windows\CurrentVersion\Uninstall\Quiz' /v DisplayName /t REG_SZ /d 'Quiz' /f >/dev/null 2>&1 || true
  "$WINEBIN" reg add 'HKLM\Software\ComputerHouse\Quiz' /v InstallPath /t REG_SZ /d 'C:\Pyrus\Quiz' /f >/dev/null 2>&1 || true
  "$WINEBIN" reg add 'HKLM\Software\ComputerHouse\Quiz' /v SourcePath /t REG_SZ /d 'D:\Quiz' /f >/dev/null 2>&1 || true
  "$WINEBIN" reg add 'HKCU\Software\ComputerHouse\Quiz' /v InstallPath /t REG_SZ /d 'C:\Pyrus\Quiz' /f >/dev/null 2>&1 || true
  "$WINEBIN" reg add 'HKCU\Software\ComputerHouse\Quiz' /v SourcePath /t REG_SZ /d 'D:\Quiz' /f >/dev/null 2>&1 || true
  # If Pyrus still chooses the component installer path, make that path harmless:
  # in the extracted working CD tree D:\Quiz\Setup.exe becomes a copy of the
  # actual Quiz launcher. The original Win16 installer is kept as Setup.installer.exe.
  if [[ "${PYRUS_REDIRECT_QUIZ_SETUP:-1}" == "1" && -f "$CDROM/Quiz/Quiz.exe" ]]; then
    if [[ -f "$CDROM/Quiz/Setup.exe" ]] && ! cmp -s "$CDROM/Quiz/Setup.exe" "$CDROM/Quiz/Quiz.exe"; then
      [[ -f "$CDROM/Quiz/Setup.installer.exe" ]] || cp -a "$CDROM/Quiz/Setup.exe" "$CDROM/Quiz/Setup.installer.exe"
      cp -a "$CDROM/Quiz/Quiz.exe" "$CDROM/Quiz/Setup.exe"
    fi
  fi
fi
# Optional local 32-bit GStreamer plugin bundle for Wine/Quartz AVI playback.
# Fedora often has only x86_64 GStreamer extras installed; Wine's 32-bit Quartz
# needs i686 plugins/codecs for the old Cinepak AVI clips used by PyrusView.
LOCAL_GST_ROOT="$HERE/local-gst-root"
if [[ "${PYRUS_USE_LOCAL_GST:-1}" == "1" && -d "$LOCAL_GST_ROOT/usr/lib/gstreamer-1.0" ]]; then
  export LD_LIBRARY_PATH="$LOCAL_GST_ROOT/usr/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
  export GST_PLUGIN_PATH_1_0="$LOCAL_GST_ROOT/usr/lib/gstreamer-1.0${GST_PLUGIN_PATH_1_0:+:$GST_PLUGIN_PATH_1_0}"
  export GST_PLUGIN_SYSTEM_PATH_1_0="/usr/lib/gstreamer-1.0:$LOCAL_GST_ROOT/usr/lib/gstreamer-1.0${GST_PLUGIN_SYSTEM_PATH_1_0:+:$GST_PLUGIN_SYSTEM_PATH_1_0}"
  export GST_REGISTRY_1_0="${GST_REGISTRY_1_0:-$PREFIX/gstreamer-registry-i686.bin}"
fi
# PyrusView uses old DirectShow/AVI playback.  Register Wine's Quartz/DirectShow
# filters once so in-game movie buttons do not crash in FilterMapper enumeration.
if [[ "${PYRUS_REGISTER_QUARTZ:-1}" == "1" && ! -f "$PREFIX/.pyrus-quartz-registered" ]]; then
  "$WINEBIN" regsvr32 /s quartz.dll >/dev/null 2>&1 || true
  "$WINEBIN" regsvr32 /s devenum.dll >/dev/null 2>&1 || true
  "$WINEBIN" regsvr32 /s qcap.dll >/dev/null 2>&1 || true
  "$WINEBIN" regsvr32 /s avifil32.dll >/dev/null 2>&1 || true
  touch "$PREFIX/.pyrus-quartz-registered"
fi
# The standalone PyrusView AVI player is more stable without Wine Explorer's
# virtual desktop; on this Wine/X11 stack it can finish/tear down with X11
# BadWindow under explorer even after the movie path itself is fixed.
if [[ "$CMD" == *"PyrusView.exe Movie"* || -z "$DESKTOP" ]]; then
  exec "$WINEBIN" cmd /c "$CMD"
fi
if [[ "$CENTER_WINDOW" == "1" && -n "${DISPLAY:-}" ]]; then
  PYRUS_DESKTOP_TITLE="${DESKTOP%%,*}" PYRUS_DESKTOP_SIZE="${DESKTOP#*,}" python3 - <<'PY' >/dev/null 2>&1 &
import ctypes, ctypes.util, os, re, time

title = os.environ.get('PYRUS_DESKTOP_TITLE', 'Pyrus')
size = os.environ.get('PYRUS_DESKTOP_SIZE', '640x480')
m = re.match(r'^(\d+)x(\d+)$', size)
want_w, want_h = (int(m.group(1)), int(m.group(2))) if m else (640, 480)

lib = ctypes.CDLL(ctypes.util.find_library('X11') or 'libX11.so.6')
Display_p = ctypes.c_void_p
Window = ctypes.c_ulong
Atom = ctypes.c_ulong

lib.XOpenDisplay.argtypes = [ctypes.c_char_p]
lib.XOpenDisplay.restype = Display_p
lib.XDefaultRootWindow.argtypes = [Display_p]
lib.XDefaultRootWindow.restype = Window
lib.XDefaultScreen.argtypes = [Display_p]
lib.XDefaultScreen.restype = ctypes.c_int
lib.XDisplayWidth.argtypes = [Display_p, ctypes.c_int]
lib.XDisplayWidth.restype = ctypes.c_int
lib.XDisplayHeight.argtypes = [Display_p, ctypes.c_int]
lib.XDisplayHeight.restype = ctypes.c_int
lib.XInternAtom.argtypes = [Display_p, ctypes.c_char_p, ctypes.c_int]
lib.XInternAtom.restype = Atom
lib.XFetchName.argtypes = [Display_p, Window, ctypes.POINTER(ctypes.c_char_p)]
lib.XFetchName.restype = ctypes.c_int
lib.XQueryTree.argtypes = [Display_p, Window, ctypes.POINTER(Window), ctypes.POINTER(Window), ctypes.POINTER(ctypes.POINTER(Window)), ctypes.POINTER(ctypes.c_uint)]
lib.XQueryTree.restype = ctypes.c_int
lib.XMoveResizeWindow.argtypes = [Display_p, Window, ctypes.c_int, ctypes.c_int, ctypes.c_uint, ctypes.c_uint]
lib.XMapRaised.argtypes = [Display_p, Window]
lib.XFlush.argtypes = [Display_p]
lib.XFree.argtypes = [ctypes.c_void_p]
lib.XCloseDisplay.argtypes = [Display_p]

d = lib.XOpenDisplay(os.environ.get('DISPLAY', '').encode() or None)
if not d:
    raise SystemExit
root = lib.XDefaultRootWindow(d)
screen = lib.XDefaultScreen(d)
screen_w = lib.XDisplayWidth(d, screen)
screen_h = lib.XDisplayHeight(d, screen)
x = max(0, (screen_w - want_w) // 2)
y = max(0, (screen_h - want_h) // 2)

def children(win):
    root_ret = Window(); parent_ret = Window(); kids = ctypes.POINTER(Window)(); n = ctypes.c_uint()
    if not lib.XQueryTree(d, win, ctypes.byref(root_ret), ctypes.byref(parent_ret), ctypes.byref(kids), ctypes.byref(n)):
        return []
    out = [kids[i] for i in range(n.value)]
    if kids:
        lib.XFree(kids)
    return out

def name(win):
    p = ctypes.c_char_p()
    if lib.XFetchName(d, win, ctypes.byref(p)) and p.value:
        s = p.value.decode(errors='ignore')
        lib.XFree(p)
        return s
    return ''

deadline = time.time() + 8
while time.time() < deadline:
    for w in children(root):
        if title.lower() in name(w).lower():
            lib.XMoveResizeWindow(d, w, x, y, want_w, want_h)
            lib.XMapRaised(d, w)
            lib.XFlush(d)
            lib.XCloseDisplay(d)
            raise SystemExit
    time.sleep(0.2)
lib.XCloseDisplay(d)
PY
fi
exec "$WINEBIN" explorer /desktop="$DESKTOP" cmd /c "$CMD"
