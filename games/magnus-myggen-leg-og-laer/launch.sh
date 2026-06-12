#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO_PATH="${MM1_ISO_PATH:-$SCRIPT_DIR/Magnus-Myggen-Leg-og-Laer.iso}"
CD_DIR="${MM1_CD_DIR:-$SCRIPT_DIR/cdrom}"
LOOP_DEVICE=""
USE_LOOP_CDROM="${MM1_USE_LOOP_CDROM:-1}"
PREFIX="${WINEPREFIX:-${MM1_WINEPREFIX:-$SCRIPT_DIR/wineprefix32}}"
WINE_BIN="${MM1_WINE_BIN:-}"
CD_DRIVE="${MM1_CD_DRIVE:-d}"
DESKTOP_SIZE="${MM1_DESKTOP_SIZE:-640x480}"
DESKTOP_NAME="${MM1_DESKTOP_NAME:-MagnusMyggenLegOgLaer}"
CENTER_WINDOW="${MM1_CENTER_WINDOW:-1}"
SAVE_DIR="${MM1_SAVE_DIR:-$PREFIX/drive_c/MAGNUS}"
INSTALL_DIR="${MM1_INSTALL_DIR:-$PREFIX/drive_c/MAGNUS}"
WINVER="${MM1_WINVER:-win98}"
MODE="${MM1_MODE:-game}"   # game (= installed stable default), cdgame (= direct CD), installed, setup, stavedit, vfwsetup
DRY_RUN="${MM1_DRY_RUN:-0}"
NO_VIRTUAL_DESKTOP="${MM1_NO_VIRTUAL_DESKTOP:-1}"
LOCK_FILE="${MM1_LOCK_FILE:-$SCRIPT_DIR/.mm1-launch.lock}"

log() { printf '[MM1] %s\n' "$*"; }
fatal() { printf '[MM1] ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

choose_wine() {
  if [[ -n "$WINE_BIN" ]]; then
    command -v "$WINE_BIN" >/dev/null 2>&1 || fatal "MM1_WINE_BIN findes ikke: $WINE_BIN"
    printf '%s\n' "$WINE_BIN"
  elif command -v wine32 >/dev/null 2>&1; then
    printf 'wine32\n'
  elif command -v wine >/dev/null 2>&1; then
    printf 'wine\n'
  else
    fatal 'Mangler wine/wine32'
  fi
}

acquire_launch_lock() {
  if command -v flock >/dev/null 2>&1; then
    mkdir -p "$(dirname "$LOCK_FILE")"
    exec 9>"$LOCK_FILE"
    flock -n 9 || fatal "Magnus & Myggen kører allerede. Stop evt. med: WINEPREFIX='$PREFIX' wineserver -k"
  fi
}

prepare_disc() {
  if [[ -f "$CD_DIR/MAGNUS.EXE" ]]; then
    if [[ -w "$CD_DIR" ]]; then
      printf 'MAGNUS_LEGOGLEAR\n' > "$CD_DIR/.windows-label"
    fi
    prepare_loop_cdrom || true
    return 0
  fi

  [[ -f "$ISO_PATH" ]] || fatal "Hverken cdrom/MAGNUS.EXE eller ISO blev fundet"
  need_cmd 7z
  log "Udpakker ISO til $CD_DIR"
  rm -rf "$CD_DIR"
  mkdir -p "$CD_DIR"
  # Denne WinISO-image giver 'Incorrect big-endian headers' med 7z efter at filerne er udpakket.
  # Accepter derfor exit-koden hvis MAGNUS.EXE faktisk kom ud.
  7z x -y -o"$CD_DIR" "$ISO_PATH" >/dev/null || true
  [[ -f "$CD_DIR/MAGNUS.EXE" ]] || fatal "MAGNUS.EXE blev ikke fundet i $CD_DIR"
  if [[ -w "$CD_DIR" ]]; then
    printf 'MAGNUS_LEGOGLEAR\n' > "$CD_DIR/.windows-label"
  fi
  prepare_loop_cdrom || log "Bruger udpakket CD-mappe som fallback: $CD_DIR"
}

prepare_loop_cdrom() {
  [[ "$USE_LOOP_CDROM" == "1" ]] || return 1
  command -v udisksctl >/dev/null 2>&1 || return 1
  command -v findmnt >/dev/null 2>&1 || return 1
  command -v losetup >/dev/null 2>&1 || return 1

  local dev mountpoint existing setup_out
  existing="$(losetup -j "$ISO_PATH" | awk -F: 'NR==1 {print $1}')"
  if [[ -n "$existing" ]]; then
    dev="$existing"
  else
    setup_out="$(udisksctl loop-setup -f "$ISO_PATH" 2>/dev/null || true)"
    dev="$(printf '%s\n' "$setup_out" | sed -n "s/.* as \(\/dev\/loop[0-9]*\).*/\1/p" | tail -1)"
  fi
  [[ -n "${dev:-}" && -b "$dev" ]] || return 1
  udisksctl mount -b "$dev" >/dev/null 2>&1 || true
  mountpoint="$(findmnt -n -o TARGET "$dev" 2>/dev/null | head -1)"
  [[ -n "$mountpoint" && -f "$mountpoint/MAGNUS.EXE" ]] || return 1
  LOOP_DEVICE="$dev"
  CD_DIR="$mountpoint"
  log "Bruger loop-mountet ISO som CD-ROM: $CD_DIR ($LOOP_DEVICE)"
}

prepare_prefix() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  if [[ ! -f "$PREFIX/system.reg" ]]; then
    log "Initialiserer 32-bit Wine-prefix: $PREFIX"
    export WINEARCH=win32
    timeout "${MM1_WINEBOOT_TIMEOUT:-120s}" "$wine" wineboot -u >/dev/null 2>&1 || true
    command -v wineserver >/dev/null 2>&1 && WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
  fi
  [[ -f "$PREFIX/system.reg" ]] || fatal "Wine-prefix blev ikke initialiseret korrekt: $PREFIX"
  prepare_installed_copy
  # MMSYS.DLL hotpatch er fjernet: patchen blokerer Win16 memory allocation
  # og spillet virker kun korrekt via D:\MAGNUS.EXE (cdgame mode) uden patch.
  mkdir -p "$PREFIX/dosdevices"
  rm -f "$PREFIX/dosdevices/${CD_DRIVE}:"
  ln -sfn "$CD_DIR" "$PREFIX/dosdevices/${CD_DRIVE}:"
  # Win16 GetDriveType/CD checks are happier when d:: points at the real
  # loop block device for the ISO.  If loop mounting failed, fall back to
  # registry-only CD-ROM mapping; do not create a text d:: marker file.
  rm -f "$PREFIX/dosdevices/${CD_DRIVE}::"
  if [[ -n "$LOOP_DEVICE" && -b "$LOOP_DEVICE" ]]; then
    ln -s "$LOOP_DEVICE" "$PREFIX/dosdevices/${CD_DRIVE}::"
  fi
  "$wine" reg add 'HKCU\Software\Wine' /v Version /d "$WINVER" /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKCU\Software\Wine\Drives' /v "${CD_DRIVE}:" /d cdrom /f >/dev/null 2>&1 || true
  write_magnus_ini
}

prepare_installed_copy() {
  if [[ ! -f "$INSTALL_DIR/MAGNUS.EXE" ]]; then
    log "Opretter manuel installeret kopi i C:\\MAGNUS"
    mkdir -p "$INSTALL_DIR"
    # Copy the Win16 runtime pieces locally, like the original installer would.
    # Large media/resources may still be read from the real CD-ROM D:.
    cp -f "$SCRIPT_DIR/cdrom"/*.{EXE,DLL,DXR,ICO,HLP,INI,WRI,TXT} "$INSTALL_DIR/" 2>/dev/null || true
  fi
  [[ -f "$INSTALL_DIR/MAGNUS.EXE" ]] || fatal "Kunne ikke oprette installeret kopi: $INSTALL_DIR/MAGNUS.EXE"
  patch_magnus_exe_heap
}

patch_magnus_exe_heap() {
  # MAGNUS.EXE er en Win16 NE-binær som Macromedia Director 4 runtime.
  # NE-headeren har flags ved +0x0c og initial heap ved +0x10.
  # VIGTIGT: +0x0c må ikke patches; det gør GUI EXE'en til en DLL og Wine
  # ender med blank Explorer/"Bad EXE format". Den oprindelige heap ved +0x10
  # er 0x0100, hvilket er for lille til Director 4's DXR/resource loading.
  # Fix: Sæt initial heap til 0x8000 (32768 bytes), som ligger under
  # automatic data-segmentets ekstra plads (~0x82c0). 0xb000 er for højt
  # for denne NE og kan give "OPTLOAD -- Error loading module".
  local target="$INSTALL_DIR/MAGNUS.EXE"
  [[ -f "$target" ]] || return 0
  python3 - "$target" <<'PY'
from pathlib import Path
import struct, sys

p = Path(sys.argv[1])
data = bytearray(p.read_bytes())
ne_off = struct.unpack_from('<H', data, 0x3c)[0]
if data[ne_off:ne_off+2] != b'NE':
    sys.exit(0)
# NE header layout: +0x0c is FLAGS, +0x10 is initial local heap size.
# Do NOT write +0x0c: that turns this GUI EXE into a DLL and Wine shows
# "Bad EXE format" / blank Explorer desktop.
heap_off = ne_off + 0x10
current = struct.unpack_from('<H', data, heap_off)[0]
target_heap = 0x8000
if current < target_heap:
    struct.pack_into('<H', data, heap_off, target_heap)
    p.write_bytes(bytes(data))
    print(f"[MM1] MAGNUS.EXE init_heap: 0x{current:04x} -> 0x{target_heap:04x}")
PY
}

patch_installed_mmsys() {
  # Wine 11 can still trip over the original Win16 MMSYS helper logic when the
  # installed copy is launched from C:. Patch only the installed C:\MAGNUS copy
  # and keep the bundled CD/ISO copy untouched.
  local target="$INSTALL_DIR/MMSYS.DLL"
  local source="$SCRIPT_DIR/cdrom/MMSYS.DLL"
  [[ -f "$source" ]] || fatal "Mangler original MMSYS.DLL på CD'en"
  mkdir -p "$INSTALL_DIR"
  python3 - "$target" "$source" <<'PY'
from pathlib import Path
import sys

target = Path(sys.argv[1])
source = Path(sys.argv[2])
orig = source.read_bytes()

if not target.exists() or target.stat().st_size != len(orig):
    target.write_bytes(orig)

b = bytearray(target.read_bytes())
seg = 0x600
patches = {
    0x0002: bytes.fromhex('31c0ca0400'),
    0x0160: bytes.fromhex('b80100ca0200'),
    0x022f: bytes.fromhex('31c0ca0200'),
    0x0355: bytes.fromhex('31c0cb'),
    0x03b7: bytes.fromhex('31c0cb'),
}
changed = False
for off, data in patches.items():
    at = seg + off
    if b[at:at+len(data)] != data:
        b[at:at+len(data)] = data
        changed = True
if changed:
    target.write_bytes(b)
PY
}

write_magnus_ini() {
  # This title's CD-check consults MAGNUS.INI and expects the original media
  # drive there. When the bundled AppImage launches the installed copy from C:,
  # writing PATH=C:\MAGNUS makes the game look for the original CD in C: and it
  # shows the classic "den originale CD sidde i drev C:" dialog. Keep the
  # global MAGNUS.INI pointed at the real CD drive, but also drop a local copy
  # inside C:\MAGNUS for the installed tree itself.
  local cd_win="${CD_DRIVE^^}"
  mkdir -p "$SAVE_DIR"
  local ini
  for ini in "$PREFIX/drive_c/windows/MAGNUS.INI" "$PREFIX/drive_c/MAGNUS.INI"; do
    mkdir -p "$(dirname "$ini")"
    cat > "$ini" <<EOF
[MAGNUS]
PATH=$cd_win
Path=$cd_win
CDDrv=${CD_DRIVE^^}
CDDrive=${CD_DRIVE^^}
EOF
  done
  mkdir -p "$INSTALL_DIR"
  cat > "$INSTALL_DIR/MAGNUS.INI" <<EOF
[MAGNUS]
PATH=$cd_win
Path=$cd_win
CDDrv=${CD_DRIVE^^}
CDDrive=${CD_DRIVE^^}
EOF
  if [[ -w "$CD_DIR" ]]; then
    cat > "$CD_DIR/MAGNUS.INI" <<EOF
[MAGNUS]
PATH=$cd_win
Path=$cd_win
CDDrv=${CD_DRIVE^^}
CDDrive=${CD_DRIVE^^}
EOF
  fi
}

select_exe() {
  case "$MODE" in
    game|installed) printf 'C:\\\\MAGNUS\\\\MAGNUS.EXE\n' ;;
    cdgame) printf '%s:\\\\MAGNUS.EXE\n' "${CD_DRIVE^^}" ;;
    setup) printf '%s:\\\\SETUP.EXE\n' "${CD_DRIVE^^}" ;;
    stavedit) printf '%s:\\\\STAVEDIT.EXE\n' "${CD_DRIVE^^}" ;;
    vfwsetup) printf '%s:\\\\VFW\\\\SETUP.EXE\n' "${CD_DRIVE^^}" ;;
    *) fatal "Ukendt MM1_MODE=$MODE (brug game/cdgame/installed/setup/stavedit/vfwsetup)" ;;
  esac
}

start_center_helper() {
  [[ "$CENTER_WINDOW" == "1" ]] || return 0
  [[ -n "${DISPLAY:-}" ]] || return 0
  local width height title
  IFS=x read -r width height <<<"$DESKTOP_SIZE"
  title="$DESKTOP_NAME - Wine Desktop"
  python3 - "$title" "$width" "$height" >/dev/null 2>&1 <<'PY' &
import ctypes, ctypes.util, sys, time

title = sys.argv[1].encode('utf-8', 'replace')
w = int(sys.argv[2]); h = int(sys.argv[3])
lib = ctypes.cdll.LoadLibrary(ctypes.util.find_library('X11') or 'libX11.so.6')

class XWindowAttributes(ctypes.Structure):
    _fields_ = [
        ('x', ctypes.c_int), ('y', ctypes.c_int),
        ('width', ctypes.c_int), ('height', ctypes.c_int),
        ('border_width', ctypes.c_int), ('depth', ctypes.c_int),
        ('visual', ctypes.c_void_p), ('root', ctypes.c_ulong),
        ('class', ctypes.c_int), ('bit_gravity', ctypes.c_int),
        ('win_gravity', ctypes.c_int), ('backing_store', ctypes.c_int),
        ('backing_planes', ctypes.c_ulong), ('backing_pixel', ctypes.c_ulong),
        ('save_under', ctypes.c_int), ('colormap', ctypes.c_ulong),
        ('map_installed', ctypes.c_int), ('map_state', ctypes.c_int),
        ('all_event_masks', ctypes.c_long), ('your_event_mask', ctypes.c_long),
        ('do_not_propagate_mask', ctypes.c_long), ('override_redirect', ctypes.c_int),
        ('screen', ctypes.c_void_p),
    ]

ERROR_HANDLER = ctypes.CFUNCTYPE(ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p)
def ignore_xerror(display, error_event):
    return 0
_err_cb = ERROR_HANDLER(ignore_xerror)

lib.XOpenDisplay.argtypes = [ctypes.c_char_p]
lib.XOpenDisplay.restype = ctypes.c_void_p
lib.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
lib.XDefaultRootWindow.restype = ctypes.c_ulong
lib.XDefaultScreen.argtypes = [ctypes.c_void_p]
lib.XDefaultScreen.restype = ctypes.c_int
lib.XDisplayWidth.argtypes = [ctypes.c_void_p, ctypes.c_int]
lib.XDisplayWidth.restype = ctypes.c_int
lib.XDisplayHeight.argtypes = [ctypes.c_void_p, ctypes.c_int]
lib.XDisplayHeight.restype = ctypes.c_int
lib.XInternAtom.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]
lib.XInternAtom.restype = ctypes.c_ulong
lib.XGetWindowProperty.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_ulong, ctypes.c_long, ctypes.c_long, ctypes.c_int, ctypes.c_ulong, ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_int), ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.c_ulong), ctypes.POINTER(ctypes.POINTER(ctypes.c_ulong))]
lib.XGetWindowProperty.restype = ctypes.c_int
lib.XFetchName.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(ctypes.c_char_p)]
lib.XFetchName.restype = ctypes.c_int
lib.XGetWindowAttributes.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(XWindowAttributes)]
lib.XGetWindowAttributes.restype = ctypes.c_int
lib.XMoveResizeWindow.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_int, ctypes.c_uint, ctypes.c_uint]
lib.XMoveResizeWindow.restype = ctypes.c_int
lib.XMapRaised.argtypes = [ctypes.c_void_p, ctypes.c_ulong]
lib.XMapRaised.restype = ctypes.c_int
lib.XFlush.argtypes = [ctypes.c_void_p]
lib.XSync.argtypes = [ctypes.c_void_p, ctypes.c_int]
lib.XSetErrorHandler.argtypes = [ERROR_HANDLER]

lib.XSetErrorHandler(_err_cb)
d = lib.XOpenDisplay(None)
if not d:
    raise SystemExit(0)
root = lib.XDefaultRootWindow(d)
screen = lib.XDefaultScreen(d)
sw, sh = lib.XDisplayWidth(d, screen), lib.XDisplayHeight(d, screen)
px = max(0, (sw - w) // 2)
py = max(0, (sh - h) // 2)
net_client_list = lib.XInternAtom(d, b'_NET_CLIENT_LIST', False)
actual_type = ctypes.c_ulong(); actual_format = ctypes.c_int()
nitems = ctypes.c_ulong(); bytes_after = ctypes.c_ulong(); prop = ctypes.POINTER(ctypes.c_ulong)()

def top_windows():
    rc = lib.XGetWindowProperty(d, root, net_client_list, 0, 4096, False, 0, ctypes.byref(actual_type), ctypes.byref(actual_format), ctypes.byref(nitems), ctypes.byref(bytes_after), ctypes.byref(prop))
    if rc != 0 or not prop:
        return []
    return [prop[i] for i in range(nitems.value)]

def window_name(win):
    out = ctypes.c_char_p()
    if lib.XFetchName(d, win, ctypes.byref(out)) and out.value:
        return out.value
    return b''

for _ in range(100):
    for win in top_windows():
        if window_name(win) == title:
            attr = XWindowAttributes()
            if lib.XGetWindowAttributes(d, win, ctypes.byref(attr)):
                lib.XMoveResizeWindow(d, win, px, py, w, h)
                lib.XMapRaised(d, win)
                lib.XSync(d, False)
                raise SystemExit(0)
    time.sleep(0.1)
PY
}

main() {
  local wine exe
  wine="$(choose_wine)"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Dry-run"
    log "ISO=$ISO_PATH"
    log "CD_DIR=$CD_DIR"
    log "PREFIX=$PREFIX"
    log "WINE=$wine"
    log "MODE=$MODE"
    log "DESKTOP=${DESKTOP_NAME},${DESKTOP_SIZE}"
    log "CENTER_WINDOW=$CENTER_WINDOW"
    return 0
  fi
  acquire_launch_lock
  prepare_disc
  prepare_prefix "$wine"
  exe="$(select_exe)"
  export WINEDEBUG="${WINEDEBUG:--all}"
  log "Starter Magnus & Myggen: Leg og Lær ($exe)"
  start_center_helper
  cd "$CD_DIR"
  if [[ "${NO_VIRTUAL_DESKTOP}" == "1" ]]; then
    log "Starter direkte via winevdm uden Wine Explorer virtual desktop (MM1_NO_VIRTUAL_DESKTOP=1)"
    # Win16 NE-programmer skal startes via winevdm. Direkte `wine C:\\...EXE`
    # kan give "Bad EXE format", og Wine Explorer virtual desktop kan give
    # blankt vindue/OPTLOAD/X11 BadWindow for dette Director 4-spil.
    exec "$wine" 'C:\windows\system32\winevdm.exe' --app-name "$exe" "$exe"
  else
    # Brug "start /exec" som wrapper for at Wine venter på Win16 NE-processen.
    # Direkte "wine explorer /desktop=... exe" detacher Win16-applikationen og
    # returnerer EXIT:0 straks -- spillet kører aldrig til afslutning.
    exec "$wine" start /exec \
      explorer "/desktop=${DESKTOP_NAME},${DESKTOP_SIZE}" "$exe"
  fi
}

main "$@"
