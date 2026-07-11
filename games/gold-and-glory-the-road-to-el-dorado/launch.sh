#!/usr/bin/env bash
set -Eeuo pipefail

GAME_ID="gold-and-glory-the-road-to-el-dorado"
GAME_TITLE="Gold and Glory: The Road to El Dorado"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${GGED_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${GGED_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ISO_PATH="${GGED_ISO:-$SOURCE_DIR/ED_CD.iso}"
CDROM_DIR="${GGED_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
EXTRACTED_CDROM_DIR="$CDROM_DIR"
PREFIX="${WINEPREFIX:-${GGED_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}}"
INSTALL_DIR_WIN="C:\\ElDorado"
INSTALL_DIR_UNIX="$PREFIX/drive_c/ElDorado"
WINE_BIN="${GGED_WINE_BIN:-}"
LOCAL_WINE_GE="$REPO_ROOT/local/runners/wine-ge-8-26/bin/wine"
if [[ -z "${WINEPREFIX+x}" && -z "${GGED_WINEPREFIX+x}" && -x "$LOCAL_WINE_GE" ]]; then
  PREFIX="$RUNTIME_DIR/wine-ge-prefix"
  INSTALL_DIR_UNIX="$PREFIX/drive_c/ElDorado"
fi
SEVENZ_BIN="${GGED_SEVENZ_BIN:-7z}"
CD_DRIVE="${GGED_CD_DRIVE:-d}"
CD_LABEL="${GGED_CD_LABEL:-ED_CD}"
CD_BACKEND="${GGED_CD_BACKEND:-loop}"
MODE="${GGED_MODE:-${1:-cdgame}}"
DRY_RUN="${GGED_DRY_RUN:-0}"
FORCE_WIN32="${GGED_FORCE_WIN32:-1}"
WINVER="${GGED_WINVER:-win98}"
WINEBOOT_TIMEOUT="${GGED_WINEBOOT_TIMEOUT:-240s}"
DESKTOP_NAME="${GGED_DESKTOP_NAME:-GoldGlory}"
DESKTOP_SIZE="${GGED_DESKTOP_SIZE:-640x480}"
VIRTUAL_DESKTOP="${GGED_VIRTUAL_DESKTOP:-1}"
CENTER_WINDOW="${GGED_CENTER_WINDOW:-1}"
CENTER_SIZE="${GGED_CENTER_SIZE:-640x480}"
WINEDEBUG_VALUE="${GGED_WINEDEBUG:--all}"
LOCK_FILE="${GGED_LOCK_FILE:-$RUNTIME_DIR/.launch.lock}"
LOCK_PID_FILE="${GGED_LOCK_PID_FILE:-$LOCK_FILE.pid}"
LOOP_DEVICE=""
LOOP_MOUNT=""

log() { printf '[Gold and Glory] %s\n' "$*"; }
fatal() { printf '[Gold and Glory] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

cleanup_loop_cdrom() {
  if [[ -z "$LOOP_DEVICE" ]]; then
    release_launch_lock
    return 0
  fi
  WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
  rm -f "$PREFIX/dosdevices/${CD_DRIVE}:" "$PREFIX/dosdevices/${CD_DRIVE}::"
  if [[ -d "$EXTRACTED_CDROM_DIR" ]]; then
    ln -s "$EXTRACTED_CDROM_DIR" "$PREFIX/dosdevices/${CD_DRIVE}:" 2>/dev/null || true
  fi
  udisksctl unmount -b "$LOOP_DEVICE" >/dev/null 2>&1 || true
  udisksctl loop-delete -b "$LOOP_DEVICE" >/dev/null 2>&1 || true
  LOOP_DEVICE=""
  LOOP_MOUNT=""
  release_launch_lock
}

trap cleanup_loop_cdrom EXIT
trap 'cleanup_loop_cdrom; exit 143' INT TERM

choose_wine() {
  if [[ -n "$WINE_BIN" ]]; then
    command -v "$WINE_BIN" >/dev/null 2>&1 || [[ -x "$WINE_BIN" ]] || fatal "GGED_WINE_BIN findes ikke: $WINE_BIN"
    printf '%s\n' "$WINE_BIN"
  elif [[ -x "$LOCAL_WINE_GE" ]]; then
    printf '%s\n' "$LOCAL_WINE_GE"
  elif command -v wine32 >/dev/null 2>&1; then
    printf 'wine32\n'
  elif command -v wine >/dev/null 2>&1; then
    printf 'wine\n'
  else
    fatal 'Mangler wine32/wine'
  fi
}

start_center_window_helper() {
  [[ "$CENTER_WINDOW" == "1" && -n "${DISPLAY:-}" ]] || return 0
  local title='El Dorado'
  [[ "$VIRTUAL_DESKTOP" == "1" ]] && title="$DESKTOP_NAME - Wine desktop"
  "$SCRIPT_DIR/center_window.py" "$title" "$CENTER_SIZE" >/dev/null 2>&1 &
}

acquire_launch_lock() {
  mkdir -p "$RUNTIME_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || fatal "Gold and Glory kører allerede for dette prefix. Luk spillet, eller kør: GGED_MODE=kill ./launch.sh"
    printf '%s\n' "$$" > "$LOCK_PID_FILE"
  fi
}

release_launch_lock() {
  if [[ -f "$LOCK_PID_FILE" && "$(<"$LOCK_PID_FILE")" == "$$" ]]; then
    rm -f "$LOCK_PID_FILE"
  fi
}

extract_cdrom() {
  if [[ -f "$CDROM_DIR/engine/linc/engine.exe" && -f "$CDROM_DIR/engine/eldorado.ini" && -f "$CDROM_DIR/gmovies/intro.bik" ]]; then
    return 0
  fi
  [[ -f "$ISO_PATH" ]] || fatal "ISO mangler: $ISO_PATH. Kør ./install.sh --download --no-launch, eller sæt GGED_ISO."
  need_cmd "$SEVENZ_BIN"
  log "Udpakker ISO til runtime CD-ROM: $CDROM_DIR"
  rm -rf "$CDROM_DIR.tmp"
  mkdir -p "$CDROM_DIR.tmp"
  "$SEVENZ_BIN" x -y -o"$CDROM_DIR.tmp" "$ISO_PATH" >/dev/null
  [[ -f "$CDROM_DIR.tmp/engine/linc/engine.exe" ]] || fatal "Udpakket ISO mangler engine/linc/engine.exe"
  [[ -f "$CDROM_DIR.tmp/engine/eldorado.ini" ]] || fatal "Udpakket ISO mangler engine/eldorado.ini"
  [[ -f "$CDROM_DIR.tmp/gmovies/intro.bik" ]] || fatal "Udpakket ISO mangler gmovies/intro.bik"
  rm -rf "$CDROM_DIR"
  mv "$CDROM_DIR.tmp" "$CDROM_DIR"
  printf '%s\n' "$CD_LABEL" > "$CDROM_DIR/.windows-label" 2>/dev/null || true
}

setup_loop_cdrom() {
  [[ -f "$ISO_PATH" ]] || fatal "ISO mangler: $ISO_PATH. Kør ./install.sh --download --no-launch, eller sæt GGED_ISO."
  need_cmd udisksctl
  local loop_output mount_output
  log "Mapper original ISO som loop-backed CD-ROM"
  loop_output="$(udisksctl loop-setup -f "$ISO_PATH")" || fatal "Kunne ikke oprette loop-device for ISO"
  [[ "$loop_output" =~ (/dev/loop[0-9]+) ]] || fatal "Kan ikke læse loop-device fra: $loop_output"
  LOOP_DEVICE="${BASH_REMATCH[1]}"
  mount_output="$(udisksctl mount -b "$LOOP_DEVICE")" || fatal "Kunne ikke mounte $LOOP_DEVICE"
  [[ "$mount_output" =~ \ at\ (.+)$ ]] || fatal "Kan ikke læse mountpoint fra: $mount_output"
  LOOP_MOUNT="${BASH_REMATCH[1]%.}"
  [[ -f "$LOOP_MOUNT/engine/linc/engine.exe" ]] || fatal "Loop-mounted ISO mangler engine/linc/engine.exe"
  CDROM_DIR="$LOOP_MOUNT"
}

prepare_cdrom_media() {
  case "$CD_BACKEND" in
    loop) setup_loop_cdrom ;;
    extract) extract_cdrom ;;
    *) fatal "Ukendt GGED_CD_BACKEND '$CD_BACKEND' (brug loop eller extract)" ;;
  esac
}

repair_broken_prefix_if_needed() {
  if [[ -d "$PREFIX" && ! -d "$PREFIX/drive_c/windows" ]]; then
    local backup="${PREFIX}.broken.$(date +%Y%m%d-%H%M%S)"
    log "Finder halvfærdig Wine-prefix uden drive_c/windows; flytter til $backup"
    mv "$PREFIX" "$backup"
  fi
}

prepare_prefix() {
  local wine="$1" cd_device_path="$LOOP_DEVICE"
  export WINEPREFIX="$PREFIX"
  export WINEDEBUG="$WINEDEBUG_VALUE"
  mkdir -p "$(dirname "$PREFIX")"
  if [[ "$FORCE_WIN32" == "1" && ! -f "$PREFIX/system.reg" ]]; then
    export WINEARCH=win32
  fi
  if [[ ! -f "$PREFIX/system.reg" ]]; then
    log "Initialiserer Wine-prefix: $PREFIX"
    timeout "$WINEBOOT_TIMEOUT" "$wine" wineboot -u >/dev/null 2>&1 || true
    command -v wineserver >/dev/null 2>&1 && WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
  fi
  [[ -f "$PREFIX/system.reg" ]] || fatal "Wine-prefix blev ikke initialiseret korrekt"
  mkdir -p "$PREFIX/dosdevices"
  rm -f "$PREFIX/dosdevices/${CD_DRIVE}:" "$PREFIX/dosdevices/${CD_DRIVE}::"
  ln -s "$CDROM_DIR" "$PREFIX/dosdevices/${CD_DRIVE}:"
  if [[ -n "$LOOP_DEVICE" ]]; then
    # Wine-GE tries to read d:: directly. The udisks-created /dev/loopN is not
    # readable by this user, while the original ISO is; use it as the backing
    # device only for the local Wine-GE runner.
    if [[ "$wine" == "$LOCAL_WINE_GE" || "${GGED_WINE_GE:-0}" == "1" ]] && [[ -r "$ISO_PATH" ]]; then
      cd_device_path="$ISO_PATH"
    fi
    ln -s "$cd_device_path" "$PREFIX/dosdevices/${CD_DRIVE}::"
  fi
  "$wine" reg add 'HKCU\Software\Wine\Drives' /v "${CD_DRIVE}:" /d cdrom /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKCU\Software\Wine' /v Version /d "$WINVER" /f >/dev/null 2>&1 || true
}

prepare_manual_install_tree() {
  [[ -f "$PREFIX/system.reg" ]] || fatal "prepare_prefix skal køres før prepare_manual_install_tree"
  if [[ -f "$INSTALL_DIR_UNIX/engine/linc/engine.exe" && -f "$INSTALL_DIR_UNIX/engine/eldorado.ini" ]]; then
    return 0
  fi
  log "Bygger manuel C:\\ElDorado runtime fra CD'ens engine/ mappe"
  rm -rf "$INSTALL_DIR_UNIX.tmp" "$INSTALL_DIR_UNIX"
  mkdir -p "$INSTALL_DIR_UNIX.tmp"
  cp -a "$CDROM_DIR/engine" "$INSTALL_DIR_UNIX.tmp/engine"
  mkdir -p "$INSTALL_DIR_UNIX.tmp/engine/linc/saves"
  mv "$INSTALL_DIR_UNIX.tmp" "$INSTALL_DIR_UNIX"
}

register_install_state() {
  local wine="$1"
  "$wine" reg add 'HKCU\Software\RevolutionSoftware\ElDorado' /v Path /d "$INSTALL_DIR_WIN" /f >/dev/null 2>&1 || true
}

wait_for_wine_processes() {
  local wine="$1" wine_path wineserver_bin
  wine_path="$(readlink -f "$wine" 2>/dev/null || printf '%s' "$wine")"
  wineserver_bin="$(dirname "$wine_path")/wineserver"
  if [[ -x "$wineserver_bin" ]]; then
    WINEPREFIX="$PREFIX" "$wineserver_bin" -w
  else
    WINEPREFIX="$PREFIX" wineserver -w
  fi
}

wine_run_cmd() {
  local wine="$1" cmd="$2"
  export WINEPREFIX="$PREFIX"
  export WINEDEBUG="$WINEDEBUG_VALUE"
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    start_center_window_helper
    "$wine" explorer "/desktop=$DESKTOP_NAME,$DESKTOP_SIZE" cmd /c "$cmd"
    wait_for_wine_processes "$wine"
    return
  fi
  start_center_window_helper
  "$wine" cmd /c "$cmd"
}

run_cdgame() {
  local wine="$1"
  wine_run_cmd "$wine" "cd /d ${CD_DRIVE^^}:\\engine\\linc && engine.exe"
}

run_installed() {
  local wine="$1"
  prepare_manual_install_tree
  register_install_state "$wine"
  wine_run_cmd "$wine" 'cd /d C:\ElDorado\engine\linc && engine.exe'
}

run_setup() {
  local wine="$1"
  wine_run_cmd "$wine" "cd /d ${CD_DRIVE^^}:\\ && setup.exe"
}

if [[ "$DRY_RUN" == "1" ]]; then
  printf 'GAME_ID=%s\nSOURCE_DIR=%s\nRUNTIME_DIR=%s\nISO_PATH=%s\nCDROM_DIR=%s\nPREFIX=%s\nCD_BACKEND=%s\nMODE=%s\n' \
    "$GAME_ID" "$SOURCE_DIR" "$RUNTIME_DIR" "$ISO_PATH" "$CDROM_DIR" "$PREFIX" "$CD_BACKEND" "$MODE"
  exit 0
fi

wine="$(choose_wine)"
case "$MODE" in
  kill)
    if [[ -f "$LOCK_PID_FILE" ]]; then
      lock_pid="$(<"$LOCK_PID_FILE")"
      if [[ "$lock_pid" =~ ^[0-9]+$ ]] && kill -0 "$lock_pid" 2>/dev/null; then
        log "Stopper låst launcher-proces $lock_pid"
        kill -KILL "$lock_pid" 2>/dev/null || true
      fi
      rm -f "$LOCK_PID_FILE"
    fi
    WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
    exit 0
    ;;
  prepare)
    acquire_launch_lock
    prepare_cdrom_media
    repair_broken_prefix_if_needed
    prepare_prefix "$wine"
    prepare_manual_install_tree
    register_install_state "$wine"
    log "Runtime klar: $RUNTIME_DIR"
    exec 9>&- 2>/dev/null || true
    ;;
  cdgame|cdroot|game)
    acquire_launch_lock
    prepare_cdrom_media
    repair_broken_prefix_if_needed
    prepare_prefix "$wine"
    run_cdgame "$wine"
    ;;
  installed|manual)
    acquire_launch_lock
    prepare_cdrom_media
    repair_broken_prefix_if_needed
    prepare_prefix "$wine"
    run_installed "$wine"
    ;;
  setup)
    acquire_launch_lock
    prepare_cdrom_media
    repair_broken_prefix_if_needed
    prepare_prefix "$wine"
    run_setup "$wine"
    ;;
  *)
    fatal "Ukendt mode '$MODE' (brug cdgame, installed, setup, prepare eller kill)"
    ;;
esac
