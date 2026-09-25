#!/usr/bin/env bash
# Official patch experiments only; never modifies the physical reference runtime.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
BASE="$(retro_runtime_dir "$ROOT" battlefield-vietnam)"
SOURCE="$BASE/physical-ge7/prefix-gameplay-confirmed"
RUNTIME="$BASE/patch121-ge7"
PATCHES="$(retro_source_dir "$ROOT" battlefield-vietnam)/patches"
WINE="$ROOT/local/runners/lutris-GE-Proton7-43-x86_64/bin/wine"
SERVER="$(dirname "$WINE")/wineserver"
fail() { printf '%s\n' "$*" >&2; exit 1; }
MODE="${1:-help}"
case "$MODE" in prepare|1.2|1.21) ;; *) fail 'Usage: patch-official.sh prepare|1.2|1.21';; esac
[[ -x "$WINE" && -x "$SERVER" ]] || fail 'Tested Wine runner missing'
# Refuse aliases before logs/locks/Wine. No external game-directory symlinks.
python3 - "$BASE" "$SOURCE" "$RUNTIME" <<'PY'
from pathlib import Path
import sys
base,source,runtime=map(Path,sys.argv[1:])
protected=[base/'physical-ge7',source,base/'physical-ge7/prefix']
for candidate in [runtime,runtime/'prefix']:
 for target in protected:
  a,b=candidate.resolve(),target.resolve()
  if a==b or a in b.parents or b in a.parents: sys.exit('Unsafe runtime overlap')
for p in [source,source/'drive_c',runtime,runtime/'prefix']:
 if p.is_symlink(): sys.exit('Unexpected prefix/runtime symlink')
game=source/'drive_c/Program Files/EA GAMES/Battlefield Vietnam'
if not game.is_dir(): sys.exit('Preserved installed source missing')
for p in [game,*game.parents]:
 if p.is_symlink(): sys.exit('Game directory must not alias external files')
PY
unset WINEARCH WINEDLLOVERRIDES WINEDLLPATH
export WINEDEBUG=-all
if [[ "$MODE" == prepare ]]; then
  [[ ! -e "$RUNTIME" ]] || fail 'Experiment already exists; refusing overwrite'
  exec 8>"$BASE/physical-ge7/.lock"
  flock -n 8 || fail 'Physical runtime busy'
  WINEPREFIX="$SOURCE" timeout 20 "$SERVER" -w 8>&- || fail 'Source Wine still running; not copying'
  mkdir "$RUNTIME"
  cp -a --reflink=auto -- "$SOURCE" "$RUNTIME/prefix"
  printf 'Preserved source copied to %s\n' "$RUNTIME/prefix"
  exit
fi
[[ -f "$RUNTIME/prefix/system.reg" ]] || fail 'Run prepare first'
mkdir -p "$RUNTIME/logs"
exec 9>"$RUNTIME/.lock"
flock -n 9 || fail 'Patch runtime busy'
export WINEPREFIX="$RUNTIME/prefix"
timeout 20 "$SERVER" -w 9>&- || fail 'Experiment Wine still running'
case "$MODE" in
  1.2) PATCH="$PATCHES/bfv_v1_2.exe";;
  1.21) PATCH="$PATCHES/bfv_v1_21.exe";;
esac
[[ -f "$PATCH" ]] || fail "Missing original official patch: $PATCH"
cd "$PATCHES"
rc=0
"$WINE" "$PATCH" 9>&- >"$RUNTIME/logs/patch-$MODE.log" 2>&1 || rc=$?
"$SERVER" -w 9>&-
printf 'Installer exit=%s; verify installed version and gameplay separately.\n' "$rc"
exit "$rc"
