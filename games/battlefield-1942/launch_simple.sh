#!/usr/bin/env bash
# Explicit opt-in community-patched variant, not the official retail baseline.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
RUNTIME="${BF1942_SIMPLE_RUNTIME:-$(retro_runtime_dir "$ROOT" battlefield-1942)/simple161b}"
WINE="${BF1942_WINE:-$ROOT/local/runners/lutris-GE-Proton7-43-x86_64/bin/wine}"
[[ "$RUNTIME" == /* ]] || { printf 'Runtime must be absolute\n' >&2; exit 1; }
[[ -f "$RUNTIME/logs/simple-patch-manifest.json" && -f "$RUNTIME/prefix/system.reg" ]] || { printf 'Run prepare-simple.sh first\n' >&2; exit 1; }
SERVER="$(dirname "$WINE")/wineserver"
[[ -x "$WINE" && -x "$SERVER" ]] || { printf 'Missing paired Wine runner\n' >&2; exit 1; }
unset WINEARCH WINEDLLOVERRIDES WINEDLLPATH
export WINEPREFIX="$RUNTIME/prefix" WINEDEBUG="${BF1942_DEBUG:--all}"
GAME="$WINEPREFIX/drive_c/Program Files/EA GAMES/Battlefield 1942"
[[ -f "$GAME/BF1942.exe" ]] || { printf 'Missing game executable\n' >&2; exit 1; }
exec 9>"$RUNTIME/.launch.lock"
flock -n 9 || { printf 'This variant is already running\n' >&2; exit 1; }
cd "$GAME"
LOG="$RUNTIME/logs/game-$(date +%Y%m%d-%H%M%S).log"
printf 'SiMPLE community variant\nWine: %s\nLog: %s\n' "$WINE" "$LOG"
rc=0
"$WINE" BF1942.exe "$@" 9>&- >"$LOG" 2>&1 || rc=$?
"$SERVER" -w 9>&-
exit "$rc"
