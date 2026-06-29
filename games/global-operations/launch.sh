#!/usr/bin/env bash
set -Eeuo pipefail

GAME_ID="global-operations"
GAME_TITLE="Global Operations"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${GO_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${GO_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ISO_PATH="${GO_ISO:-$SOURCE_DIR/Global Operations (Europe) (En,Fr,De).iso}"
CDROM_DIR="${GO_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
INSTALL_DIR="${GO_INSTALL_DIR:-$RUNTIME_DIR/installed/GlobalOps}"
PREFIX="${WINEPREFIX:-${GO_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}}"
WINE_BIN="${GO_WINE_BIN:-}"
SEVENZ_BIN="${GO_SEVENZ_BIN:-7z}"
CD_DRIVE="${GO_CD_DRIVE:-d}"
CD_LABEL="${GO_CD_LABEL:-GLOBALOPS}"
MODE="${GO_MODE:-${1:-game}}"
DRY_RUN="${GO_DRY_RUN:-0}"
FORCE_WIN32="${GO_FORCE_WIN32:-1}"
WINVER="${GO_WINVER:-winxp}"
WINEBOOT_TIMEOUT="${GO_WINEBOOT_TIMEOUT:-120s}"
DESKTOP_NAME="${GO_DESKTOP_NAME:-GlobalOperations}"
DESKTOP_SIZE="${GO_DESKTOP_SIZE:-1024x768}"
VIRTUAL_DESKTOP="${GO_VIRTUAL_DESKTOP:-1}"
WINEDEBUG_VALUE="${GO_WINEDEBUG:--all}"
LOCK_FILE="${GO_LOCK_FILE:-$RUNTIME_DIR/.launch.lock}"

log() { printf '[Global Operations] %s\n' "$*"; }
fatal() { printf '[Global Operations] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

choose_wine() {
  if [[ -n "$WINE_BIN" ]]; then
    command -v "$WINE_BIN" >/dev/null 2>&1 || [[ -x "$WINE_BIN" ]] || fatal "GO_WINE_BIN findes ikke: $WINE_BIN"
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
    flock -n 9 || fatal "Global Operations kører allerede for dette prefix. Luk spillet, eller kør: GO_MODE=kill ./launch.sh"
  fi
}

extract_cdrom() {
  if [[ -f "$CDROM_DIR/globalops.exe" && -f "$CDROM_DIR/secdrv.sys" && -f "$CDROM_DIR/Setup/GAME/Engine.REZ" ]]; then
    return 0
  fi
  [[ -f "$ISO_PATH" ]] || fatal "ISO mangler: $ISO_PATH. Kør ./install.sh --download --no-launch, eller sæt GO_ISO."
  need_cmd "$SEVENZ_BIN"
  log "Udpakker ISO til runtime CD-ROM: $CDROM_DIR"
  rm -rf "$CDROM_DIR.tmp"
  mkdir -p "$CDROM_DIR.tmp"
  "$SEVENZ_BIN" x -y -o"$CDROM_DIR.tmp" "$ISO_PATH" >/dev/null
  [[ -f "$CDROM_DIR.tmp/globalops.exe" ]] || fatal "Udpakket ISO mangler globalops.exe"
  [[ -f "$CDROM_DIR.tmp/secdrv.sys" ]] || fatal "Udpakket ISO mangler secdrv.sys"
  [[ -f "$CDROM_DIR.tmp/Setup/GAME/Engine.REZ" ]] || fatal "Udpakket ISO mangler Setup/GAME/Engine.REZ"
  rm -rf "$CDROM_DIR"
  mv "$CDROM_DIR.tmp" "$CDROM_DIR"
  printf '%s\n' "$CD_LABEL" > "$CDROM_DIR/.windows-label" 2>/dev/null || true
}

prepare_manual_install_tree() {
  extract_cdrom
  if [[ -f "$INSTALL_DIR/globalops.exe" && -f "$INSTALL_DIR/Engine.REZ" && -f "$INSTALL_DIR/mss32.dll" ]]; then
    return 0
  fi
  log "Bygger manuel runtime-install fra CD'ens Setup/GAME + root globalops.exe"
  rm -rf "$INSTALL_DIR.tmp"
  mkdir -p "$INSTALL_DIR.tmp"
  cp -a "$CDROM_DIR/Setup/GAME/." "$INSTALL_DIR.tmp/"
  cp -a "$CDROM_DIR/globalops.exe" "$INSTALL_DIR.tmp/globalops.exe"
  cp -a "$CDROM_DIR/uzi.ico" "$INSTALL_DIR.tmp/uzi.ico" 2>/dev/null || true
  rm -rf "$INSTALL_DIR"
  mkdir -p "$(dirname "$INSTALL_DIR")"
  mv "$INSTALL_DIR.tmp" "$INSTALL_DIR"
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

wine_run() {
  local wine="$1" cwd="$2" target="$3"
  export WINEPREFIX="$PREFIX"
  export WINEDEBUG="$WINEDEBUG_VALUE"
  cd "$cwd"
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    exec "$wine" explorer "/desktop=$DESKTOP_NAME,$DESKTOP_SIZE" "$target"
  fi
  exec "$wine" "$target"
}

run_game() {
  local wine="$1"
  prepare_manual_install_tree
  wine_run "$wine" "$INSTALL_DIR" "globalops.exe"
}

run_cdgame() {
  local wine="$1"
  prepare_manual_install_tree
  wine_run "$wine" "$INSTALL_DIR" "${CD_DRIVE^^}:\\globalops.exe"
}

run_autorun() {
  local wine="$1"
  extract_cdrom
  wine_run "$wine" "$CDROM_DIR" "${CD_DRIVE^^}:\\AutoRun.exe"
}

run_setup() {
  local wine="$1"
  extract_cdrom
  wine_run "$wine" "$CDROM_DIR/Setup" "${CD_DRIVE^^}:\\Setup\\Setup.exe"
}

if [[ "$DRY_RUN" == "1" ]]; then
  printf 'GAME_ID=%s\nSOURCE_DIR=%s\nRUNTIME_DIR=%s\nISO_PATH=%s\nCDROM_DIR=%s\nINSTALL_DIR=%s\nPREFIX=%s\nMODE=%s\n' \
    "$GAME_ID" "$SOURCE_DIR" "$RUNTIME_DIR" "$ISO_PATH" "$CDROM_DIR" "$INSTALL_DIR" "$PREFIX" "$MODE"
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
    prepare_manual_install_tree
    repair_broken_prefix_if_needed
    prepare_prefix "$wine"
    log "Runtime klar: $RUNTIME_DIR"
    exec 9>&- 2>/dev/null || true
    ;;
  game|installed)
    acquire_launch_lock
    extract_cdrom
    repair_broken_prefix_if_needed
    prepare_prefix "$wine"
    run_game "$wine"
    ;;
  cdgame|cdroot)
    acquire_launch_lock
    extract_cdrom
    repair_broken_prefix_if_needed
    prepare_prefix "$wine"
    run_cdgame "$wine"
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
    fatal "Ukendt mode '$MODE' (brug game, cdgame, autorun, setup, prepare eller kill)"
    ;;
esac
