#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GAME_ID="uden-at-prale-det-er-harry"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${HARRY_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${HARRY_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ISO_PATH="${HARRY_ISO:-$SOURCE_DIR/uden-at-prale-det-er-harry.iso}"
CDROM_DIR="${HARRY_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
WINEPREFIX="${HARRY_WINEPREFIX:-$RUNTIME_DIR/wineprefix}"
export WINEPREFIX
export WINEDEBUG="${WINEDEBUG:--all}"
DESKTOP_SIZE="${HARRY_DESKTOP_SIZE:-800x600}"
MODE="${1:-${HARRY_MODE:-game}}"
GAME_DIR="$WINEPREFIX/drive_c/Harry"
LOCK_FILE="$RUNTIME_DIR/.launch.lock"

log() { printf '[Harry] %s\n' "$*"; }
fatal() { printf '[Harry] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

resolve_wine() {
  if [[ -n "${HARRY_WINE:-}" ]]; then
    WINE_BIN="$HARRY_WINE"
  elif command -v wine32 >/dev/null 2>&1; then
    WINE_BIN="$(command -v wine32)"
  elif command -v wine >/dev/null 2>&1; then
    WINE_BIN="$(command -v wine)"
  else
    fatal "Mangler wine32/wine"
  fi
  [[ -x "$WINE_BIN" ]] || fatal "Wine er ikke eksekverbar: $WINE_BIN"

  if [[ -n "${HARRY_WINESERVER:-}" ]]; then
    WINESERVER_BIN="$HARRY_WINESERVER"
  elif command -v wineserver >/dev/null 2>&1; then
    WINESERVER_BIN="$(command -v wineserver)"
  else
    WINESERVER_BIN="$WINE_BIN"
  fi
}

extract_cdrom_if_needed() {
  if [[ -f "$CDROM_DIR/CDmenu.exe" && -f "$CDROM_DIR/setup.exe" ]]; then
    return 0
  fi
  [[ -f "$ISO_PATH" ]] || fatal "ISO mangler: $ISO_PATH. Kør ./install.sh --download eller ./install.sh --existing først."
  need_cmd 7z
  log "Udpakker ISO til runtime CD-ROM: $CDROM_DIR"
  rm -rf "$CDROM_DIR"
  mkdir -p "$CDROM_DIR" "$RUNTIME_DIR/logs"
  7z x -y -o"$CDROM_DIR" "$ISO_PATH" >"$RUNTIME_DIR/logs/extract.log"
  [[ -f "$CDROM_DIR/CDmenu.exe" ]] || fatal "CDmenu.exe mangler efter udpakning"
  [[ -f "$CDROM_DIR/setup.exe" ]] || fatal "setup.exe mangler efter udpakning"
}

init_prefix_if_needed() {
  if [[ -f "$WINEPREFIX/system.reg" ]]; then
    return 0
  fi
  log "Initialiserer Wine-prefix: $WINEPREFIX"
  mkdir -p "$(dirname "$WINEPREFIX")"
  export WINEARCH="${HARRY_WINEARCH:-win32}"
  timeout "${HARRY_WINEBOOT_TIMEOUT:-120}" "$WINE_BIN" wineboot -u >/dev/null 2>&1 || true
}

map_cd_drive() {
  mkdir -p "$WINEPREFIX/dosdevices"
  ln -sfn "$CDROM_DIR" "$WINEPREFIX/dosdevices/d:"
  rm -f "$WINEPREFIX/dosdevices/d::"
  printf 'HARRY\n' > "$CDROM_DIR/.windows-label"

  # Vigtig detalje for dette spil: CD-checken virker med D: som en almindelig
  # Wine drive med label HARRY. Registry cdrom-markering kan få vol d: til at
  # larme eller få spillet til stadig at afvise CD'en.
  "$WINE_BIN" reg delete 'HKCU\Software\Wine\Drives' /v 'd:' /f >/dev/null 2>&1 || true
  "$WINE_BIN" reg add 'HKCU\Software\Wine' /v Version /t REG_SZ /d win98 /f >/dev/null 2>&1 || true
}

install_game_if_needed() {
  if [[ -x "$GAME_DIR/harry.exe" ]]; then
    return 0
  fi
  if [[ "${HARRY_AUTO_INSTALL:-1}" != "1" ]]; then
    fatal "Installeret Harry mangler: $GAME_DIR/harry.exe. Kør HARRY_MODE=setup ./launch.sh eller slå HARRY_AUTO_INSTALL=1 til."
  fi
  log "Installerer Harry stille fra Inno Setup"
  cd "$CDROM_DIR"
  "$WINE_BIN" 'D:\setup.exe' /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR='C:\Harry'
  [[ -x "$GAME_DIR/harry.exe" ]] || fatal "Installationen blev færdig, men $GAME_DIR/harry.exe mangler"
}

launch_wine_desktop() {
  local target="$1" cwd="$2"
  cd "$cwd"
  exec "$WINE_BIN" explorer "/desktop=Harry,$DESKTOP_SIZE" "$target"
}

main() {
  mkdir -p "$RUNTIME_DIR"
  resolve_wine

  case "$MODE" in
    kill)
      if [[ "$WINESERVER_BIN" == "$WINE_BIN" ]]; then
        exec "$WINE_BIN" wineserver -k
      else
        exec "$WINESERVER_BIN" -k
      fi
      ;;
  esac

  (
    flock 9
    extract_cdrom_if_needed
    init_prefix_if_needed
    map_cd_drive
    case "$MODE" in
      setup|install|cdmenu|menu) : ;;
      game|installed) install_game_if_needed ;;
      *) fatal "Ukendt HARRY_MODE=$MODE; brug game, cdmenu, setup eller kill" ;;
    esac
  ) 9>"$LOCK_FILE"

  case "$MODE" in
    game|installed) launch_wine_desktop 'C:\Harry\harry.exe' "$GAME_DIR" ;;
    cdmenu|menu) launch_wine_desktop 'D:\CDmenu.exe' "$CDROM_DIR" ;;
    setup|install) launch_wine_desktop 'D:\setup.exe' "$CDROM_DIR" ;;
  esac
}

main "$@"
