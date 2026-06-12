#!/usr/bin/env bash
set -Eeuo pipefail

GAME_ID="magnus-myggen-den-store-skattejagt"
GAME_TITLE="Magnus & Myggen: Den Store Skattejagt"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${MM2_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${MM2_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
CUE_PATH="${MM2_CUE:-${MM2_CUE_PATH:-$SOURCE_DIR/MM2NORD.cue}}"
BIN_PATH="${MM2_BIN:-${MM2_BIN_PATH:-$SOURCE_DIR/MM2NORD.bin}}"
ISO_PATH="${MM2_ISO:-${MM2_ISO_PATH:-$SOURCE_DIR/MM2NORD.iso}}"
CD_DIR="${MM2_CD_DIR:-$RUNTIME_DIR/cdrom}"
INSTALL_DIR="${MM2_INSTALL_DIR:-$RUNTIME_DIR/installed-dk}"
PREFIX="${WINEPREFIX:-${MM2_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}}"
WINE_BIN="${MM2_WINE_BIN:-}"
CD_DRIVE="${MM2_CD_DRIVE:-d}"
DESKTOP_SIZE="${MM2_DESKTOP_SIZE:-800x600}"
# Keep the game constrained in a Wine virtual desktop by default. Direct fullscreen
# can create a real mm2run.exe window that appears black/off-screen on this setup.
VIRTUAL_DESKTOP="${MM2_VIRTUAL_DESKTOP:-1}"
CENTER_WINDOW="${MM2_CENTER_WINDOW:-1}"
CENTER_SECONDS="${MM2_CENTER_SECONDS:-35}"
MODE="${MM2_MODE:-${1:-game}}"
DRY_RUN="${MM2_DRY_RUN:-0}"
FORCE_WIN32="${MM2_FORCE_WIN32:-1}"
WINVER="${MM2_WINVER:-win98}"
WINEBOOT_TIMEOUT="${MM2_WINEBOOT_TIMEOUT:-90s}"
LOCK_FILE="${MM2_LOCK_FILE:-$RUNTIME_DIR/.launch.lock}"
UNSHIELD_BIN="${MM2_UNSHIELD:-}"
UNSHIELD_LIBRARY_PATH="${MM2_UNSHIELD_LIBRARY_PATH:-}"

log() { printf '[MM2] %s\n' "$*"; }
fatal() { printf '[MM2] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

choose_wine() {
  if [[ -n "$WINE_BIN" ]]; then
    command -v "$WINE_BIN" >/dev/null 2>&1 || [[ -x "$WINE_BIN" ]] || fatal "MM2_WINE_BIN findes ikke: $WINE_BIN"
    printf '%s\n' "$WINE_BIN"
  elif command -v wine32 >/dev/null 2>&1; then
    printf 'wine32\n'
  elif command -v wine >/dev/null 2>&1; then
    printf 'wine\n'
  else
    fatal 'Mangler wine32/wine'
  fi
}

find_unshield() {
  if [[ -n "$UNSHIELD_BIN" ]]; then
    [[ -x "$UNSHIELD_BIN" ]] || fatal "MM2_UNSHIELD er ikke eksekverbar: $UNSHIELD_BIN"
    printf '%s\n' "$UNSHIELD_BIN"
    return 0
  fi
  if command -v unshield >/dev/null 2>&1; then
    command -v unshield
    return 0
  fi
  if [[ -x /home/test/.local/bin/unshield ]]; then
    printf '%s\n' /home/test/.local/bin/unshield
    return 0
  fi
  return 1
}

run_unshield() {
  local unshield="$1"; shift
  if [[ -n "$UNSHIELD_LIBRARY_PATH" ]]; then
    LD_LIBRARY_PATH="$UNSHIELD_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$unshield" "$@"
  elif [[ "$unshield" == /home/test/.local/bin/unshield && -d /home/test/.local/pkg/unshield-rpm/usr/lib64 ]]; then
    LD_LIBRARY_PATH="/home/test/.local/pkg/unshield-rpm/usr/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$unshield" "$@"
  else
    "$unshield" "$@"
  fi
}

acquire_launch_lock() {
  mkdir -p "$RUNTIME_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || fatal "MM2 kører allerede for dette prefix. Luk spillet/WineDbg, eller kør: MM2_MODE=kill ./launch.sh"
  fi
}

convert_bin_to_iso_if_needed() {
  if [[ -f "$ISO_PATH" ]]; then
    return 0
  fi
  [[ -f "$BIN_PATH" ]] || return 1
  [[ -f "$CUE_PATH" ]] || return 1
  if ! grep -Eq 'TRACK[[:space:]]+01[[:space:]]+MODE1/2352' "$CUE_PATH"; then
    fatal "CUE er ikke den forventede single-track MODE1/2352 disk: $CUE_PATH"
  fi
  need_cmd python3
  log "Konverterer BIN/CUE MODE1/2352 til ISO: $ISO_PATH"
  mkdir -p "$(dirname "$ISO_PATH")"
  python3 - "$BIN_PATH" "$ISO_PATH.tmp" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1])
out = Path(sys.argv[2])
sector = 2352
payload_start = 16
payload_end = payload_start + 2048
size = src.stat().st_size
if size % sector:
    raise SystemExit(f'BIN size {size} is not divisible by {sector}')
count = 0
with src.open('rb') as f, out.open('wb') as g:
    while True:
        s = f.read(sector)
        if not s:
            break
        if len(s) != sector:
            raise SystemExit(f'partial trailing sector: {len(s)} bytes')
        g.write(s[payload_start:payload_end])
        count += 1
if count == 0:
    raise SystemExit('no sectors converted')
PY
  mv -f "$ISO_PATH.tmp" "$ISO_PATH"
}

iso_volume_label() {
  if command -v isoinfo >/dev/null 2>&1 && [[ -f "$ISO_PATH" ]]; then
    isoinfo -d -i "$ISO_PATH" 2>/dev/null | awk -F': ' '/Volume id:/ {print $2; found=1} END {if (!found) print "MM2NORD"}'
  else
    printf 'MM2NORD\n'
  fi
}

prepare_disc() {
  if [[ ! -f "$CD_DIR/AUTORUN.INF" || ! -f "$CD_DIR/LAUNCHER.EXE" || ! -f "$CD_DIR/MM2.DAT" || ! -f "$CD_DIR/DK/MM2LNG.DAT" ]]; then
    convert_bin_to_iso_if_needed || true
    [[ -f "$ISO_PATH" ]] || fatal "ISO mangler: $ISO_PATH. Kør ./install.sh --download --no-launch, eller sæt MM2_ISO/MM2_BIN/MM2_CUE."
    need_cmd 7z
    log "Udpakker ISO til runtime CD-ROM: $CD_DIR"
    rm -rf "$CD_DIR"
    mkdir -p "$CD_DIR"
    7z x -y -o"$CD_DIR" "$ISO_PATH" >/dev/null
  fi
  [[ -f "$CD_DIR/AUTORUN.INF" ]] || fatal "AUTORUN.INF blev ikke fundet i $CD_DIR"
  [[ -f "$CD_DIR/LAUNCHER.EXE" ]] || fatal "LAUNCHER.EXE blev ikke fundet i $CD_DIR"
  [[ -f "$CD_DIR/SETUP.EXE" ]] || fatal "SETUP.EXE blev ikke fundet i $CD_DIR"
  [[ -f "$CD_DIR/DATA1.CAB" ]] || fatal "DATA1.CAB blev ikke fundet i $CD_DIR"
  [[ -f "$CD_DIR/MM2.DAT" && -f "$CD_DIR/MM2.IDX" ]] || fatal "MM2.DAT/MM2.IDX mangler i $CD_DIR"
  [[ -f "$CD_DIR/DK/MM2LNG.DAT" && -f "$CD_DIR/DK/MM2LNG.IDX" ]] || fatal "Danske MM2LNG resource-filer mangler i $CD_DIR/DK"
  iso_volume_label > "$CD_DIR/.windows-label"
}

prepare_manual_install() {
  if [[ -f "$INSTALL_DIR/MM2RUN.EXE" && -f "$INSTALL_DIR/default.pal" && -f "$INSTALL_DIR/isrt.dll" ]]; then
    return 0
  fi
  local unshield_bin
  unshield_bin="$(find_unshield || true)"
  [[ -n "$unshield_bin" ]] || fatal "Mangler unshield til manuel InstallShield-udpakning"
  log "Udpakker dansk spilprogram manuelt fra DATA1.CAB"
  rm -rf "$RUNTIME_DIR/manual-install" "$INSTALL_DIR"
  mkdir -p "$RUNTIME_DIR/manual-install" "$INSTALL_DIR"
  run_unshield "$unshield_bin" x -d "$RUNTIME_DIR/manual-install" "$CD_DIR/DATA1.CAB" >/dev/null
  [[ -f "$RUNTIME_DIR/manual-install/Program_files_DK/mm2run.exe" ]] || fatal "Program_files_DK/mm2run.exe blev ikke fundet efter unshield"
  cp -f "$RUNTIME_DIR/manual-install/Program_files_DK/mm2run.exe" "$INSTALL_DIR/MM2RUN.EXE"
  cp -f "$RUNTIME_DIR/manual-install/Program_files/ui.ico" "$INSTALL_DIR/" 2>/dev/null || true
  cp -f "$RUNTIME_DIR/manual-install/Program_files/ii.ico" "$INSTALL_DIR/" 2>/dev/null || true
  # The original InstallShield layout also drops these support files beside the
  # game executable; keep them with MM2RUN.EXE instead of relying on Wine/system
  # fallbacks.
  cp -f "$RUNTIME_DIR/manual-install/_Support_Non-SelfRegistering/default.pal" "$INSTALL_DIR/" 2>/dev/null || true
  cp -f "$RUNTIME_DIR/manual-install/_Support_Non-SelfRegistering/isrt.dll" "$INSTALL_DIR/" 2>/dev/null || true
  chmod +x "$INSTALL_DIR/MM2RUN.EXE" 2>/dev/null || true
}

prepare_prefix() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  mkdir -p "$(dirname "$PREFIX")"
  if [[ "$FORCE_WIN32" == "1" && ! -f "$PREFIX/system.reg" ]]; then
    export WINEARCH=win32
  fi
  if [[ ! -f "$PREFIX/system.reg" ]]; then
    log "Initialiserer Wine-prefix: $PREFIX"
    timeout "$WINEBOOT_TIMEOUT" "$wine" wineboot -u >/dev/null 2>&1 || true
    command -v wineserver >/dev/null 2>&1 && WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
  fi

  mkdir -p "$PREFIX/dosdevices"
  rm -f "$PREFIX/dosdevices/${CD_DRIVE}:" "$PREFIX/dosdevices/${CD_DRIVE}::"
  ln -sfn "$CD_DIR" "$PREFIX/dosdevices/${CD_DRIVE}:"

  # Avoid the first-run settings.dat crash observed with this Win95/98-era app.
  mkdir -p "$PREFIX/drive_c/ProgramData/IVANOFF/MM2/2.0"

  "$wine" reg add 'HKCU\Software\Wine' /v Version /d "$WINVER" /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKCU\Software\Wine\Drives' /v "${CD_DRIVE}:" /d cdrom /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKLM\Software\IVANOFF Interactive\MM2' /v mm2lng /t REG_SZ /d DK /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKLM\Software\IVANOFF Interactive\MM2' /v 'Resource file' /t REG_SZ /d "${CD_DRIVE^^}:\\MM2" /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKLM\Software\IVANOFF Interactive\MM2' /v 'Resource local file' /t REG_SZ /d "${CD_DRIVE^^}:\\DK\\MM2LNG" /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKLM\Software\IVANOFF Interactive\MM2' /v SoundLevel /t REG_DWORD /d 100 /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKLM\Software\IVANOFF Interactive\MM2' /v BkgMusicOn /t REG_DWORD /d 1 /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKLM\Software\IVANOFF Interactive\MM2' /v WWWLinksOff /t REG_DWORD /d 1 /f >/dev/null 2>&1 || true
}

center_wine_windows() {
  [[ "$CENTER_WINDOW" == "1" ]] || return 0
  command -v python3 >/dev/null 2>&1 || return 0
  (
    python3 - "$DESKTOP_SIZE" "$CENTER_SECONDS" <<'PY' >/dev/null 2>&1 || true
import ctypes, ctypes.util, os, re, subprocess, sys, time
size = sys.argv[1]
deadline = time.time() + float(sys.argv[2])
try:
    want_w, want_h = [int(x) for x in size.lower().split('x', 1)]
except Exception:
    want_w, want_h = 800, 600
screen_w = int(os.environ.get('MM2_SCREEN_WIDTH', '3840'))
screen_h = int(os.environ.get('MM2_SCREEN_HEIGHT', '1080'))
x = max(0, (screen_w - want_w) // 2)
y = max(0, (screen_h - want_h) // 2)
lib = ctypes.CDLL(ctypes.util.find_library('X11'))
lib.XOpenDisplay.argtypes=[ctypes.c_char_p]; lib.XOpenDisplay.restype=ctypes.c_void_p
lib.XDefaultRootWindow.argtypes=[ctypes.c_void_p]; lib.XDefaultRootWindow.restype=ctypes.c_ulong
lib.XInternAtom.argtypes=[ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int]; lib.XInternAtom.restype=ctypes.c_ulong
lib.XSendEvent.argtypes=[ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_long, ctypes.c_void_p]; lib.XSendEvent.restype=ctypes.c_int
lib.XMoveResizeWindow.argtypes=[ctypes.c_void_p, ctypes.c_ulong, ctypes.c_int, ctypes.c_int, ctypes.c_uint, ctypes.c_uint]
lib.XMapRaised.argtypes=[ctypes.c_void_p, ctypes.c_ulong]
lib.XFlush.argtypes=[ctypes.c_void_p]
lib.XSync.argtypes=[ctypes.c_void_p, ctypes.c_int]
class Data(ctypes.Union):
    _fields_=[('b',ctypes.c_char*20),('s',ctypes.c_short*10),('l',ctypes.c_long*5)]
class Client(ctypes.Structure):
    _fields_=[('type',ctypes.c_int),('serial',ctypes.c_ulong),('send_event',ctypes.c_int),('display',ctypes.c_void_p),('window',ctypes.c_ulong),('message_type',ctypes.c_ulong),('format',ctypes.c_int),('data',Data)]
class Event(ctypes.Union):
    _fields_=[('xclient',Client),('pad',ctypes.c_long*24)]
d = lib.XOpenDisplay(None)
if not d:
    raise SystemExit(0)
root = lib.XDefaultRootWindow(d)
state = lib.XInternAtom(d,b'_NET_WM_STATE',False)
fs = lib.XInternAtom(d,b'_NET_WM_STATE_FULLSCREEN',False)
maxh = lib.XInternAtom(d,b'_NET_WM_STATE_MAXIMIZED_HORZ',False)
maxv = lib.XInternAtom(d,b'_NET_WM_STATE_MAXIMIZED_VERT',False)
ClientMessage=33; mask=(1<<20)|(1<<19)
def remove_state(win, a1, a2=0):
    ev=Event(); ev.xclient.type=ClientMessage; ev.xclient.send_event=1; ev.xclient.display=d; ev.xclient.window=win; ev.xclient.message_type=state; ev.xclient.format=32
    ev.xclient.data.l[0]=0; ev.xclient.data.l[1]=a1; ev.xclient.data.l[2]=a2; ev.xclient.data.l[3]=1; ev.xclient.data.l[4]=0
    lib.XSendEvent(d, root, False, mask, ctypes.byref(ev)); lib.XFlush(d)
def candidate_windows():
    try:
        out=subprocess.check_output(['xprop','-root','_NET_CLIENT_LIST'], text=True, stderr=subprocess.DEVNULL)
    except Exception:
        return []
    wins=[]
    for wid in re.findall(r'0x[0-9a-fA-F]+', out):
        try:
            info=subprocess.check_output(['xprop','-id',wid,'WM_NAME','WM_CLASS'], text=True, stderr=subprocess.DEVNULL)
        except Exception:
            continue
        low=info.lower()
        if 'mm2run.exe' in low or 'ivanoff interactive' in low or 'magnusmyggen2 - wine desktop' in low:
            wins.append(int(wid,16))
    return wins
while time.time() < deadline:
    for win in candidate_windows():
        remove_state(win, fs)
        remove_state(win, maxh, maxv)
        lib.XMoveResizeWindow(d, win, x, y, want_w, want_h)
        lib.XMapRaised(d, win)
    lib.XSync(d, False)
    time.sleep(0.5)
PY
  ) &
}

run_windows_exe() {
  local wine="$1" exe="$2" cwd="$3"
  export WINEPREFIX="$PREFIX"
  export WINEDEBUG="${WINEDEBUG:--all}"
  log "Starter $exe med $wine"
  cd "$cwd"
  center_wine_windows
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    exec "$wine" explorer "/desktop=MagnusMyggen2,$DESKTOP_SIZE" "$exe"
  else
    exec "$wine" "$exe"
  fi
}

print_dry_run() {
  local wine="$1"
  log "Dry-run"
  log "Mode: $MODE"
  log "CUE: $CUE_PATH"
  log "BIN: $BIN_PATH"
  log "ISO: $ISO_PATH"
  log "CD-ROM runtime: $CD_DIR"
  log "Install runtime: $INSTALL_DIR"
  log "Wine: $wine"
  log "Prefix: $PREFIX"
  log "CD-ROM drev: ${CD_DRIVE}:"
  log "Virtual desktop: $VIRTUAL_DESKTOP ($DESKTOP_SIZE)"
  log "Wine Windows-version: $WINVER"
}

main() {
  local wine
  wine="$(choose_wine)"
  if [[ "$DRY_RUN" == "1" || "$MODE" == "dry-run" ]]; then
    print_dry_run "$wine"
    exit 0
  fi
  if [[ "$MODE" == "kill" ]]; then
    WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
    exit 0
  fi

  acquire_launch_lock
  prepare_disc
  prepare_prefix "$wine"

  case "$MODE" in
    prepare)
      prepare_manual_install
      log "Runtime er klar."
      ;;
    game)
      prepare_manual_install
      run_windows_exe "$wine" "$INSTALL_DIR/MM2RUN.EXE" "$INSTALL_DIR"
      ;;
    launcher|cdmenu)
      run_windows_exe "$wine" "${CD_DRIVE}:\\LAUNCHER.EXE" "$CD_DIR"
      ;;
    setup)
      run_windows_exe "$wine" "${CD_DRIVE}:\\SETUP.EXE" "$CD_DIR"
      ;;
    *)
      fatal "Ukendt MM2_MODE=$MODE (brug game, prepare, launcher, setup, dry-run eller kill)"
      ;;
  esac
}

main "$@"
