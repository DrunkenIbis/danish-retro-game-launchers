#!/usr/bin/env bash
set -Eeuo pipefail

GAME_ID="atomic-bomberman-1997"
GAME_TITLE="Atomic Bomberman"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${AB_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${AB_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ISO_PATH="${AB_ISO:-$SOURCE_DIR/Atomic Bomberman.ISO}"
CDROM_DIR="${AB_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
PREFIX="${WINEPREFIX:-${AB_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}}"
WINE_BIN="${AB_WINE_BIN:-}"
SEVENZ_BIN="${AB_SEVENZ_BIN:-7z}"
CD_DRIVE="${AB_CD_DRIVE:-d}"
CD_LABEL="${AB_CD_LABEL:-BOMBRMAN}"
MODE="${AB_MODE:-${1:-game}}"
DRY_RUN="${AB_DRY_RUN:-0}"
FORCE_WIN32="${AB_FORCE_WIN32:-1}"
WINVER="${AB_WINVER:-win98}"
WINEBOOT_TIMEOUT="${AB_WINEBOOT_TIMEOUT:-90s}"
DESKTOP_NAME="${AB_DESKTOP_NAME:-AtomicBomberman}"
DESKTOP_SIZE="${AB_DESKTOP_SIZE:-800x600}"
VIRTUAL_DESKTOP="${AB_VIRTUAL_DESKTOP:-1}"
WINEDEBUG_VALUE="${AB_WINEDEBUG:--all}"
LOCK_FILE="${AB_LOCK_FILE:-$RUNTIME_DIR/.launch.lock}"

log() { printf '[Atomic Bomberman] %s\n' "$*"; }
fatal() { printf '[Atomic Bomberman] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

choose_wine() {
  if [[ -n "$WINE_BIN" ]]; then
    command -v "$WINE_BIN" >/dev/null 2>&1 || [[ -x "$WINE_BIN" ]] || fatal "AB_WINE_BIN findes ikke: $WINE_BIN"
    printf '%s\n' "$WINE_BIN"
  elif command -v wine32 >/dev/null 2>&1; then
    printf 'wine32\n'
  elif command -v wine >/dev/null 2>&1; then
    printf 'wine\n'
  else
    fatal 'Mangler wine32/wine'
  fi
}

acquire_launch_lock() {
  mkdir -p "$RUNTIME_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || fatal "Atomic Bomberman kører allerede for dette prefix. Luk spillet, eller kør: AB_MODE=kill ./launch.sh"
  fi
}

extract_cdrom() {
  if [[ -f "$CDROM_DIR/BM95.EXE" && -f "$CDROM_DIR/AUTORUN.INF" && -f "$CDROM_DIR/CFG.INI" ]]; then
    return 0
  fi
  [[ -f "$ISO_PATH" ]] || fatal "ISO mangler: $ISO_PATH. Kør ./install.sh --download --no-launch, eller sæt AB_ISO."
  need_cmd "$SEVENZ_BIN"
  log "Udpakker ISO til runtime CD-ROM: $CDROM_DIR"
  rm -rf "$CDROM_DIR.tmp"
  mkdir -p "$CDROM_DIR.tmp"
  "$SEVENZ_BIN" x -y -o"$CDROM_DIR.tmp" "$ISO_PATH" >/dev/null
  [[ -f "$CDROM_DIR.tmp/BM95.EXE" ]] || fatal "Udpakket ISO mangler BM95.EXE"
  [[ -f "$CDROM_DIR.tmp/CFG.INI" ]] || fatal "Udpakket ISO mangler CFG.INI"
  rm -rf "$CDROM_DIR"
  mv "$CDROM_DIR.tmp" "$CDROM_DIR"
  printf '%s\n' "$CD_LABEL" > "$CDROM_DIR/.windows-label" 2>/dev/null || true
}

repair_broken_prefix_if_needed() {
  if [[ -d "$PREFIX" && ! -d "$PREFIX/drive_c/windows" ]]; then
    local backup="${PREFIX}.broken.$(date +%Y%m%d-%H%M%S)"
    log "Finder halvfærdig Wine-prefix uden drive_c/windows; flytter til $backup"
    mv "$PREFIX" "$backup"
  fi
}

prepare_prefix() {
  local wine="$1"
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
  "$wine" reg add 'HKCU\Software\Wine\Drives' /v "${CD_DRIVE}:" /d cdrom /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKCU\Software\Wine' /v Version /d "$WINVER" /f >/dev/null 2>&1 || true
}

run_game() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  cd "$CDROM_DIR"
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    exec "$wine" explorer "/desktop=$DESKTOP_NAME,$DESKTOP_SIZE" "${CD_DRIVE^^}:\\BM95.EXE"
  fi
  exec "$wine" cmd /c "cd /d ${CD_DRIVE^^}:\\ && BM95.EXE"
}

run_autorun() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  cd "$CDROM_DIR"
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    exec "$wine" explorer "/desktop=$DESKTOP_NAME,$DESKTOP_SIZE" "${CD_DRIVE^^}:\\AUTORUN.EXE"
  fi
  exec "$wine" cmd /c "cd /d ${CD_DRIVE^^}:\\ && AUTORUN.EXE"
}

run_setup() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  cd "$CDROM_DIR"
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    exec "$wine" explorer "/desktop=$DESKTOP_NAME,$DESKTOP_SIZE" "${CD_DRIVE^^}:\\SETUP.EXE"
  fi
  exec "$wine" cmd /c "cd /d ${CD_DRIVE^^}:\\ && SETUP.EXE"
}

if [[ "$DRY_RUN" == "1" ]]; then
  printf 'GAME_ID=%s\nSOURCE_DIR=%s\nRUNTIME_DIR=%s\nISO_PATH=%s\nCDROM_DIR=%s\nPREFIX=%s\nMODE=%s\n' \
    "$GAME_ID" "$SOURCE_DIR" "$RUNTIME_DIR" "$ISO_PATH" "$CDROM_DIR" "$PREFIX" "$MODE"
  exit 0
fi

wine="$(choose_wine)"
case "$MODE" in
  kill)
    WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
    exit 0
    ;;
  prepare)
    acquire_launch_lock
    extract_cdrom
    repair_broken_prefix_if_needed
    prepare_prefix "$wine"
    log "Runtime klar: $RUNTIME_DIR"
    exec 9>&- 2>/dev/null || true
    ;;
  game|cdgame)
    acquire_launch_lock
    extract_cdrom
    repair_broken_prefix_if_needed
    prepare_prefix "$wine"
    run_game "$wine"
    ;;
  autorun|cdmenu)
    acquire_launch_lock
    extract_cdrom
    repair_broken_prefix_if_needed
    prepare_prefix "$wine"
    run_autorun "$wine"
    ;;
  setup)
    acquire_launch_lock
    extract_cdrom
    repair_broken_prefix_if_needed
    prepare_prefix "$wine"
    run_setup "$wine"
    ;;
  *)
    fatal "Ukendt mode '$MODE' (brug game, autorun, setup, prepare eller kill)"
    ;;
esac