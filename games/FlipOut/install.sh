#!/usr/bin/env bash
# Original Windows autorun; no manual extraction or registration synthesis.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
RUNTIME="${FLIPOUT_RUNTIME:-$(retro_runtime_dir "$ROOT" FlipOut-physical)}"
CD="${FLIPOUT_CD:-/run/media/$USER/FLIPOUT}"
DEVICE="${FLIPOUT_DEVICE:-/dev/sr0}"
WINE="${FLIPOUT_WINE:-$ROOT/local/runners/lutris-GE-Proton7-43-x86_64/bin/wine}"
SERVER="$(dirname "$WINE")/wineserver"
export WINEPREFIX="$RUNTIME/prefix" WINEDEBUG=-all
unset WINEARCH WINEDLLOVERRIDES
[[ -x "$WINE" && -x "$SERVER" ]] || { printf 'Wine runner/server missing\n' >&2; exit 1; }
python3 - "$CD" "$DEVICE" <<'PY'
import json, os, pathlib, stat, subprocess, sys
cd, dev = map(pathlib.Path, sys.argv[1:])
assert stat.S_ISBLK(dev.stat().st_mode) and os.access(dev, os.R_OK), 'Unreadable optical device'
r = subprocess.run(['findmnt','--json','--mountpoint',str(cd),'-o','SOURCE,FSTYPE,OPTIONS'],capture_output=True,text=True,check=True)
rows=json.loads(r.stdout)['filesystems']
assert len(rows)==1 and pathlib.Path(rows[0]['source']).resolve()==dev.resolve(), 'Wrong mount source'
assert rows[0]['fstype']=='iso9660' and 'ro' in rows[0]['options'].split(','), 'Expected read-only CD'
for n in ('flipout!.exe','autorun.inf','flipdata'):
    assert len([p for p in cd.iterdir() if p.name.casefold()==n])==1, 'Wrong or ambiguous disc: '+n
PY
[[ "${1:-}" != check ]] || exit 0
mkdir -p "$RUNTIME/logs"
exec 9>"$RUNTIME/.lock"
flock -n 9 || { printf 'FlipOut is already running\n' >&2; exit 1; }
if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
  WINEARCH=win32 timeout 120 "$WINE" wineboot -i 9>&- >"$RUNTIME/logs/bootstrap.log" 2>&1
  timeout 30 "$SERVER" -w 9>&-
fi
for name in d: d::; do
  [[ ! -e "$WINEPREFIX/dosdevices/$name" || -L "$WINEPREFIX/dosdevices/$name" ]] || { printf 'Refusing non-symlink drive mapping\n' >&2; exit 1; }
done
ln -sfnT "$CD" "$WINEPREFIX/dosdevices/d:"
ln -sfnT "$DEVICE" "$WINEPREFIX/dosdevices/d::"
"$WINE" reg add 'HKCU\Software\Wine' /v Version /t REG_SZ /d win98 /f 9>&-
"$WINE" reg add 'HKCU\Software\Wine\Drives' /v d: /t REG_SZ /d cdrom /f 9>&-
"$WINE" reg query 'HKCU\Software\Wine' /v Version 9>&-
cd "$CD"
"$WINE" explorer /desktop=FlipOut,800x600 'D:\FlipOut!.exe' 9>&- >"$RUNTIME/logs/autorun.log" 2>&1
"$SERVER" -w 9>&-
