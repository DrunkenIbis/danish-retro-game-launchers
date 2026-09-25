#!/usr/bin/env bash
# Diagnostic ordinary mounted-ISO route, separate from physical-CD runtime.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
RUNTIME="${BFV_IMAGE_RUNTIME:-$(retro_runtime_dir "$ROOT" battlefield-vietnam)/loop-ge7}"
WINE="${BFV_WINE:-$ROOT/local/runners/lutris-GE-Proton7-43-x86_64/bin/wine}"
SERVER="$(dirname "$WINE")/wineserver"
ISO="${BFV_ISO:-$(retro_source_dir "$ROOT" battlefield-vietnam)/backups/BFV_1.iso}"
CD="${BFV_CD:-/run/media/$USER/BFV_1}"
[[ "$RUNTIME" == /* && "$WINE" == /* ]] || { printf 'Runtime and Wine must be absolute paths\n' >&2; exit 1; }
# Check before any media probe, Wine call, lock or log creation. Resolve aliases
# to default/custom physical runtimes AND external prefixes, including ancestors.
python3 - "$RUNTIME" "$(retro_runtime_dir "$ROOT" battlefield-vietnam)/physical-ge7" "${BFV_RUNTIME:-$(retro_runtime_dir "$ROOT" battlefield-vietnam)/physical-ge7}" <<'PY'
from pathlib import Path
import sys
runtime = Path(sys.argv[1])
for candidate in (runtime.resolve(), (runtime/'prefix').resolve()):
    for value in sys.argv[2:]:
        physical = Path(value)
        for protected in (physical.resolve(), (physical/'prefix').resolve()):
            if (candidate == protected or protected in candidate.parents
                    or candidate in protected.parents):
                sys.exit('Refusing physical/preserved prefix')
PY
[[ -x "$WINE" && -x "$SERVER" && -f "$ISO" && -r "$ISO" ]]
python3 - "$CD" "$ISO" <<'PY'
import json, subprocess, sys
from pathlib import Path
cd,iso=map(Path,sys.argv[1:])
r=subprocess.run(['findmnt','--json','--mountpoint',str(cd),'-o','SOURCE,LABEL,OPTIONS'],capture_output=True,text=True,check=True)
m=json.loads(r.stdout)['filesystems'][0]
if m['label']!='BFV_1' or 'ro' not in m['options'].split(','):sys.exit('Wrong mounted medium')
r=subprocess.run(['losetup','--json','--list','--output','NAME,BACK-FILE'],capture_output=True,text=True,check=True)
if not any(x['name']==m['source'] and Path(x['back-file']).resolve()==iso.resolve() for x in json.loads(r.stdout)['loopdevices']):sys.exit('Mount is not the selected ISO')
PY
unset WINEARCH WINEDLLOVERRIDES WINEDLLPATH
export WINEPREFIX="$RUNTIME/prefix" WINEDEBUG=-all
[[ -f "$WINEPREFIX/system.reg" ]]
mkdir -p "$RUNTIME/logs"
exec 9>"$RUNTIME/.lock"
flock -n 9
timeout 5 "$SERVER" -w 9>&-
for link in d: d::; do
 [[ ! -e "$WINEPREFIX/dosdevices/$link" || -L "$WINEPREFIX/dosdevices/$link" ]]
done
ln -sfnT "$CD" "$WINEPREFIX/dosdevices/d:"
# UDisks loop block device is not user-readable here; ISO file is readable.
ln -sfnT "$ISO" "$WINEPREFIX/dosdevices/d::"
"$WINE" reg add 'HKCU\Software\Wine\Drives' /v d: /t REG_SZ /d cdrom /f 9>&-
GAME="$WINEPREFIX/drive_c/Program Files/EA GAMES/Battlefield Vietnam"
[[ -f "$GAME/bfvietnam.exe" ]]
cd "$GAME"
rc=0
"$WINE" "$GAME/bfvietnam.exe" 9>&- >"$RUNTIME/logs/mapped-$(date +%Y%m%d-%H%M%S).log" 2>&1 || rc=$?
"$SERVER" -w 9>&- || rc=$?
exit "$rc"
