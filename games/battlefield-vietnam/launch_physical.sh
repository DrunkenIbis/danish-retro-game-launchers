#!/usr/bin/env bash
# Original physical-media gameplay is user-confirmed; disc-free remains blocked.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
RUNTIME="${BFV_RUNTIME:-$(retro_runtime_dir "$ROOT" battlefield-vietnam)/physical-ge7}"
WINE="${BFV_WINE:-$ROOT/local/runners/lutris-GE-Proton7-43-x86_64/bin/wine}"
SERVER="$(dirname "$WINE")/wineserver"
CD="${BFV_CD:-/run/media/$USER/BFV_1}"
DEVICE="${BFV_DEVICE:-/dev/sr0}"
MODE="${1:-game}"
fail() { printf 'Battlefield Vietnam: %s\n' "$*" >&2; exit 1; }
case "$MODE" in setup|autorun|game|check|dry-run) ;; *) fail 'Brug setup|autorun|game|check|dry-run';; esac
[[ "$RUNTIME" == /* && "$WINE" == /* ]] || fail 'Runtime og Wine skal være absolutte stier'
if [[ "$MODE" == dry-run ]]; then
  printf 'MODE=%s\nRUNTIME=%s\nWINE=%s\nSERVER=%s\nCD=%s\nDEVICE=%s\n' "$MODE" "$RUNTIME" "$WINE" "$SERVER" "$CD" "$DEVICE"
  exit 0
fi
[[ -x "$WINE" && -x "$SERVER" ]] || fail "Runner/parret wineserver mangler: $WINE"
python3 - "$CD" "$DEVICE" <<'PY'
import json, os, pathlib, stat, subprocess, sys
cd, dev = map(pathlib.Path, sys.argv[1:])
def fail(s): sys.exit('Battlefield Vietnam: '+s)
if not stat.S_ISBLK(dev.stat().st_mode) or not os.access(dev, os.R_OK): fail('Enheden er ikke en læsbar blok-enhed')
r=subprocess.run(['findmnt','--json','--mountpoint',str(cd),'-o','SOURCE,FSTYPE,OPTIONS,LABEL'],capture_output=True,text=True)
rows=json.loads(r.stdout or '{}').get('filesystems',[])
if len(rows)!=1 or pathlib.Path(rows[0]['source']).resolve()!=dev.resolve(): fail('Forkert CD-mount/enhed')
m=rows[0]
if m['fstype']!='iso9660' or 'ro' not in m['options'].split(',') or m.get('label')!='BFV_1': fail('Forventede skrivebeskyttet BFV_1')
for n in ['setup.exe','autorun.exe','data1.cab','setup.ini']:
 if len([p for p in cd.iterdir() if p.name.lower()==n and p.is_file()])!=1: fail('Manglende/tvetydig '+n)
print('Verificeret BFV_1:',dev,'->',cd)
PY
[[ "$MODE" != check ]] || exit 0
unset WINEARCH WINEDLLOVERRIDES WINEDLLPATH
export WINEPREFIX="$RUNTIME/prefix" WINEDEBUG="${BFV_DEBUG:--all}"
# Never enable diagnostic tracing during original setup/key entry.
[[ "$MODE" == game ]] || export WINEDEBUG=-all
mkdir -p "$RUNTIME/logs"
exec 9>"$RUNTIME/.lock"
flock -n 9 || fail 'Denne runtime er allerede i brug'
# Close lock descriptor in all Wine children; only this wrapper owns it.
if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
  [[ ! -e "$WINEPREFIX" ]] || fail 'Ufuldstændigt prefix; bevar det og vælg en ny BFV_RUNTIME'
  if ! WINEARCH=win32 timeout 120 "$WINE" wineboot -i 9>&- >"$RUNTIME/logs/bootstrap.log" 2>&1; then
    "$SERVER" -k 9>&- || true
    timeout 15 "$SERVER" -w 9>&- || true
    fail 'Wine-initialisering fejlede; se bootstrap.log'
  fi
  timeout 30 "$SERVER" -w 9>&-
fi
for link in d: d::; do
  [[ ! -e "$WINEPREFIX/dosdevices/$link" || -L "$WINEPREFIX/dosdevices/$link" ]] || fail "Uventet ikke-symlink: $link"
done
ln -sfnT "$CD" "$WINEPREFIX/dosdevices/d:"
ln -sfnT "$DEVICE" "$WINEPREFIX/dosdevices/d::"
"$WINE" reg add 'HKCU\Software\Wine\Drives' /v d: /t REG_SZ /d cdrom /f 9>&-
"$WINE" reg add 'HKCU\Software\Wine' /v Version /t REG_SZ /d winxp /f 9>&-
"$WINE" reg query 'HKCU\Software\Wine' /v Version 9>&-
LOG="$RUNTIME/logs/$MODE-$(date +%Y%m%d-%H%M%S).log"
rc=0
if [[ "$MODE" == game ]]; then
  EXE="$(python3 - "$WINEPREFIX/drive_c" <<'PY'
from pathlib import Path
import sys
hits=[p for p in Path(sys.argv[1]).rglob('*') if p.is_file() and p.name.lower()=='bfvietnam.exe']
if len(hits)!=1: sys.exit('Gennemfør originalinstallationen først; ingen entydig bfvietnam.exe')
print(hits[0])
PY
)"
  cd "$(dirname "$EXE")"
  "$WINE" "$EXE" 9>&- >"$LOG" 2>&1 || rc=$?
else
  cd "$RUNTIME"
  target=Setup.exe
  [[ "$MODE" != autorun ]] || target=Autorun.exe
  # No tracing of key-entry dialogs; the installer owns registration state.
  "$WINE" cmd /c "cd /d D:\\ && $target" 9>&- >"$LOG" 2>&1 || rc=$?
fi
"$SERVER" -w 9>&- || rc=$?
exit "$rc"
