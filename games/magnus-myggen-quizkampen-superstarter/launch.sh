#!/usr/bin/env bash
set -Eeuo pipefail

GAME_ID="magnus-myggen-quizkampen-superstarter"
GAME_TITLE="Magnus & Myggen: Quizkampen Superstarter"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${MMQ_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${MMQ_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ISO_PATH="${MMQ_ISO:-$SOURCE_DIR/Quizkampen Superstarter Version.iso}"
CDROM_DIR="${MMQ_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
INSTALL_DIR="${MMQ_INSTALL_DIR:-$RUNTIME_DIR/installed}"
PREFIX="${WINEPREFIX:-${MMQ_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}}"
CD_DRIVE="${MMQ_CD_DRIVE:-d}"
MODE="${MMQ_MODE:-${1:-game}}"
WINE_BIN="${MMQ_WINE_BIN:-${WINE_BIN:-}}"
WINVER="${MMQ_WINVER:-win98}"
FORCE_WIN32="${MMQ_FORCE_WIN32:-1}"
DESKTOP_SIZE="${MMQ_DESKTOP_SIZE:-800x600}"
VIRTUAL_DESKTOP="${MMQ_VIRTUAL_DESKTOP:-0}"
DRY_RUN="${MMQ_DRY_RUN:-0}"
LOCK_FILE="${MMQ_LOCK_FILE:-$RUNTIME_DIR/.launch.lock}"
WINEBOOT_TIMEOUT="${MMQ_WINEBOOT_TIMEOUT:-45s}"
UNSHIELD_BIN="${MMQ_UNSHIELD:-}"
UNSHIELD_LIBRARY_PATH="${MMQ_UNSHIELD_LIBRARY_PATH:-}"

log() { printf '[MMQ] %s\n' "$*"; }
fatal() { printf '[MMQ] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

choose_wine() {
  if [[ -n "$WINE_BIN" ]]; then
    command -v "$WINE_BIN" >/dev/null 2>&1 || [[ -x "$WINE_BIN" ]] || fatal "MMQ_WINE_BIN/WINE_BIN findes ikke: $WINE_BIN"
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
    [[ -x "$UNSHIELD_BIN" ]] || fatal "MMQ_UNSHIELD er ikke eksekverbar: $UNSHIELD_BIN"
    printf '%s\n' "$UNSHIELD_BIN"
    return 0
  fi
  if command -v unshield >/dev/null 2>&1; then
    command -v unshield
    return 0
  fi
  # Local fallback used by this Fedora test machine; harmless if absent.
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

iso_volume_label() {
  if command -v isoinfo >/dev/null 2>&1; then
    isoinfo -d -i "$ISO_PATH" 2>/dev/null | awk -F': ' '/Volume id:/ {print $2; found=1} END {if (!found) print "Q122DK"}'
  else
    # Observed on the archive.org ISO with `file`: ISO 9660 CD-ROM filesystem data 'Q122DK'.
    printf 'Q122DK\n'
  fi
}

prepare_cdrom() {
  if [[ ! -f "$CDROM_DIR/AUTORUN.INF" || ! -f "$CDROM_DIR/DATA1.CAB" || ! -f "$CDROM_DIR/LAUNCHER.EXE" ]]; then
    [[ -f "$ISO_PATH" ]] || fatal "ISO blev ikke fundet: $ISO_PATH. Kør ./install.sh --download --no-launch først, eller sæt MMQ_ISO."
    need_cmd 7z
    log "Udpakker ISO til runtime CD-ROM: $CDROM_DIR"
    rm -rf "$CDROM_DIR"
    mkdir -p "$CDROM_DIR"
    7z x -y -o"$CDROM_DIR" "$ISO_PATH" >/dev/null
  fi
  [[ -f "$CDROM_DIR/AUTORUN.INF" ]] || fatal "AUTORUN.INF mangler i $CDROM_DIR"
  [[ -f "$CDROM_DIR/LAUNCHER.EXE" ]] || fatal "LAUNCHER.EXE mangler i $CDROM_DIR"
  [[ -f "$CDROM_DIR/DATA1.CAB" ]] || fatal "DATA1.CAB mangler i $CDROM_DIR"
  if [[ -f "$ISO_PATH" ]]; then
    iso_volume_label > "$CDROM_DIR/.windows-label"
  elif [[ ! -f "$CDROM_DIR/.windows-label" ]]; then
    printf 'Q122DK\n' > "$CDROM_DIR/.windows-label"
  fi
}

prepare_manual_install() {
  if [[ -x "$INSTALL_DIR/mm12main.exe" && -f "$INSTALL_DIR/standard.cxt" && -d "$INSTALL_DIR/xtras" ]]; then
    return 0
  fi
  local unshield
  unshield="$(find_unshield || true)"
  [[ -n "$unshield" ]] || fatal "Mangler unshield til at udpakke InstallShield CAB manuelt"
  log "Udpakker Director-spillet manuelt fra DATA1.CAB"
  rm -rf "$RUNTIME_DIR/unshield" "$INSTALL_DIR"
  mkdir -p "$RUNTIME_DIR/unshield" "$INSTALL_DIR"
  run_unshield "$unshield" x -d "$RUNTIME_DIR/unshield" "$CDROM_DIR/DATA1.CAB" >/dev/null
  [[ -f "$RUNTIME_DIR/unshield/Application_DK/mm12main.exe" ]] || fatal "mm12main.exe blev ikke fundet efter unshield-udpakning"
  cp -a "$RUNTIME_DIR/unshield/Application_DK/." "$INSTALL_DIR/"
  mkdir -p "$INSTALL_DIR/xtras"
  cp -a "$RUNTIME_DIR/unshield/Application/xtras/." "$INSTALL_DIR/xtras/"
  cp -f "$RUNTIME_DIR/unshield/Application/UI.ICO" "$INSTALL_DIR/" 2>/dev/null || true
  chmod +x "$INSTALL_DIR/mm12main.exe" 2>/dev/null || true
  [[ -f "$INSTALL_DIR/standard.cxt" ]] || fatal "standard.cxt mangler i install-mappen"
  [[ -f "$INSTALL_DIR/locmem.cxt" ]] || fatal "locmem.cxt mangler i install-mappen"
  [[ -f "$INSTALL_DIR/qdata.cxt" ]] || fatal "qdata.cxt mangler i install-mappen"
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
  ln -sfn "$CDROM_DIR" "$PREFIX/dosdevices/${CD_DRIVE}:"
  "$wine" reg add 'HKCU\Software\Wine' /v Version /d "$WINVER" /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKCU\Software\Wine\Drives' /v "${CD_DRIVE}:" /d cdrom /f >/dev/null 2>&1 || true
}

acquire_launch_lock() {
  mkdir -p "$RUNTIME_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || fatal "Quizkampen kører allerede for dette prefix. Luk spillet, eller kør: MMQ_MODE=kill ./launch.sh"
  fi
}

run_game() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  export WINEDEBUG="${WINEDEBUG:--all}"
  cd "$INSTALL_DIR"
  log "Starter mm12main.exe fra $INSTALL_DIR"
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    exec "$wine" explorer "/desktop=Quizkampen,$DESKTOP_SIZE" "$INSTALL_DIR/mm12main.exe"
  else
    exec "$wine" "$INSTALL_DIR/mm12main.exe"
  fi
}

run_cd_exe() {
  local wine="$1" exe="$2"
  export WINEPREFIX="$PREFIX"
  cd "$CDROM_DIR"
  log "Starter ${CD_DRIVE}:\\$exe fra CD-ROM runtime"
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    exec "$wine" explorer "/desktop=Quizkampen,$DESKTOP_SIZE" "${CD_DRIVE}:\\$exe"
  else
    exec "$wine" "${CD_DRIVE}:\\$exe"
  fi
}

print_dry_run() {
  local wine="$1"
  log "Dry-run"
  log "Mode: $MODE"
  log "ISO: $ISO_PATH"
  log "CD-ROM runtime: $CDROM_DIR"
  log "Install runtime: $INSTALL_DIR"
  log "Wine-prefix: $PREFIX"
  log "Wine: $wine"
  log "CD-drev: ${CD_DRIVE}:"
  log "Winver: $WINVER"
  log "Virtual desktop: $VIRTUAL_DESKTOP ($DESKTOP_SIZE)"
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
  prepare_cdrom
  case "$MODE" in
    prepare)
      prepare_manual_install
      prepare_prefix "$wine"
      log "Runtime er klar."
      ;;
    game)
      prepare_manual_install
      prepare_prefix "$wine"
      run_game "$wine"
      ;;
    launcher|cdmenu)
      prepare_prefix "$wine"
      run_cd_exe "$wine" 'LAUNCHER.EXE'
      ;;
    setup)
      prepare_prefix "$wine"
      run_cd_exe "$wine" 'SETUP.EXE'
      ;;
    *)
      fatal "Ukendt MMQ_MODE=$MODE (brug game, prepare, launcher, setup, dry-run eller kill)"
      ;;
  esac
}

main "$@"
