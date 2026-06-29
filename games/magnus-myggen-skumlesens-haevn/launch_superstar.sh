#!/usr/bin/env bash
set -Eeuo pipefail

GAME_ID="magnus-myggen-skumlesens-haevn"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${MM3_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${MM3_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
PREFIX="${WINEPREFIX:-${MM3_WINEPREFIX:-$RUNTIME_DIR/superstarter-prefix32}}"
DESKTOP_SIZE="${MM3_DESKTOP_SIZE:-800x600}"
VIRTUAL_DESKTOP="${MM3_VIRTUAL_DESKTOP:-1}"
DRY_RUN="${MM3_DRY_RUN:-0}"
LOCK_FILE="${MM3_LOCK_FILE:-$RUNTIME_DIR/.superstarter.lock}"
WINE_BIN="${MM3_WINE_BIN:-${WINE_BIN:-}}"
SUPERSTARTER_EXE="${MM3_SUPERSTARTER_EXE:-$RUNTIME_DIR/unshield/superstarter_DK/mmsuper.exe}"
GAME_WORKDIR="${MM3_GAME_WORKDIR:-$PREFIX/drive_c/Program Files/Magnus & Myggen - Skumlesens Haevn}"
SUPERSTARTER_C_EXE="${MM3_SUPERSTARTER_C_EXE:-$GAME_WORKDIR/mmsuper.exe}"

log() { printf '[MM3-superstarter] %s\n' "$*"; }
fatal() { printf '[MM3-superstarter] FEJL: %s\n' "$*" >&2; exit 1; }

choose_wine() {
  if [[ -n "$WINE_BIN" ]]; then
    command -v "$WINE_BIN" >/dev/null 2>&1 || [[ -x "$WINE_BIN" ]] || fatal "MM3_WINE_BIN/WINE_BIN findes ikke: $WINE_BIN"
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
    flock -n 9 || fatal "SuperStarter kører allerede for dette prefix. Luk den, eller kør: WINEPREFIX=$PREFIX wineserver -k"
  fi
}

print_dry_run() {
  local wine="$1"
  log 'Dry-run'
  log "Source dir: $SOURCE_DIR"
  log "Runtime dir: $RUNTIME_DIR"
  log "Wine-prefix: $PREFIX"
  log "Wine: $wine"
  log "SuperStarter EXE: $SUPERSTARTER_EXE"
  log "Arbejdsmappe: $GAME_WORKDIR"
  log "Virtual desktop: $VIRTUAL_DESKTOP ($DESKTOP_SIZE)"
  log 'Forbereder via launch.sh MM3_MODE=prepare og starter derefter kun SuperStarter til kontrol.'
}

main() {
  local wine
  wine="$(choose_wine)"

  if [[ "$DRY_RUN" == "1" ]]; then
    print_dry_run "$wine"
    exit 0
  fi

  MM3_WINEPREFIX="$PREFIX" MM3_MODE=prepare "$SCRIPT_DIR/launch.sh"

  [[ -f "$SUPERSTARTER_EXE" ]] || fatal "SuperStarter blev ikke fundet efter prepare: $SUPERSTARTER_EXE"
  chmod +x "$SUPERSTARTER_EXE" 2>/dev/null || true
  [[ -d "$GAME_WORKDIR" ]] || fatal "Spillets arbejdsmappe mangler: $GAME_WORKDIR"
  cp -f "$SUPERSTARTER_EXE" "$SUPERSTARTER_C_EXE"
  chmod +x "$SUPERSTARTER_C_EXE" 2>/dev/null || true

  export WINEPREFIX="$PREFIX"
  export WINEDEBUG="${WINEDEBUG:--all}"
  acquire_launch_lock
  cd "$GAME_WORKDIR"

  log 'Starter separat SuperStarter-kontrol. Dette er kun til diagnosticering, ikke gameplay.'
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    log 'Starter i Wine desktop, så det visuelle resultat kan ses/captures som et samlet skrivebord.'
    exec "$wine" explorer "/desktop=MM3-SuperStarter,$DESKTOP_SIZE" 'C:\Program Files\Magnus & Myggen - Skumlesens Haevn\mmsuper.exe'
  fi
  exec "$wine" 'C:\Program Files\Magnus & Myggen - Skumlesens Haevn\mmsuper.exe'
}

main "$@"
