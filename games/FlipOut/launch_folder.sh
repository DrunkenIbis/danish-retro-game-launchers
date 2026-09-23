#!/usr/bin/env bash
# User-verified folder launch: original files, no optical media or binary changes.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
RUNTIME="${FLIPOUT_RUNTIME:-$(retro_runtime_dir "$ROOT" FlipOut-folder)}"
WINE="${FLIPOUT_WINE:-$ROOT/local/runners/lutris-GE-Proton7-43-x86_64/bin/wine}"
SERVER="$(dirname "$WINE")/wineserver"
export WINEPREFIX="$RUNTIME/prefix" WINEDEBUG=-all
unset WINEARCH WINEDLLOVERRIDES WINEDLLPATH
[[ -f "$WINEPREFIX/system.reg" && -x "$WINE" && -x "$SERVER" ]]
GAME="$WINEPREFIX/drive_c/FlipOut"
[[ -f "$GAME/flipout!.exe" && -d "$GAME/flipdata" ]]
mkdir -p "$RUNTIME/logs"
exec 9>"$RUNTIME/.lock"
flock -n 9
cd "$GAME"
"$WINE" explorer /desktop=FlipOut,800x600 'C:\FlipOut\flipout!.exe' 9>&- >"$RUNTIME/logs/folder.log" 2>&1
"$SERVER" -w 9>&-
