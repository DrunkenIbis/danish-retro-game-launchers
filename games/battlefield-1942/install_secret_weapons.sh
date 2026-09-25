#!/usr/bin/env bash
# Original expansion installer in a NEW private copy; never mutate a verified seed.
set -Eeuo pipefail
umask 077
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
BASE="$(retro_runtime_dir "$ROOT" battlefield-1942)"
SEED="${BF1942_SW_SEED:-$BASE/official161b/prefix-gameplay-verified}"
RUNTIME="${BF1942_SW_RUNTIME:-$BASE/secret-weapons}"
CD="${BF1942_SW_CD:-/run/media/test/DISC_4_SECRETWEAPONS}"
DEVICE="${BF1942_SW_DEVICE:-/dev/sr0}"
WINE="${BF1942_WINE:-$ROOT/local/runners/lutris-GE-Proton7-43-x86_64/bin/wine}"
GAME_REL='drive_c/Program Files/EA GAMES/Battlefield 1942'
[[ -f "$SEED/system.reg" && -f "$SEED/$GAME_REL/BF1942.exe" ]] || { printf 'Missing installed seed\n' >&2; exit 1; }
for p in "$SEED" "$RUNTIME" "$CD" "$DEVICE" "$WINE"; do
 [[ "$p" == /* ]] || { printf 'Paths must be absolute\n' >&2; exit 1; }
done
[[ ! -e "$RUNTIME" && ! -L "$RUNTIME" ]] || { printf 'Preserving existing runtime; choose a new BF1942_SW_RUNTIME\n' >&2; exit 1; }
SERVER="$(dirname "$WINE")/wineserver"
[[ -x "$WINE" && -x "$SERVER" ]] || { printf 'Missing paired Wine runner\n' >&2; exit 1; }
for tool in python3 flock timeout findmnt lsblk git cp; do command -v "$tool" >/dev/null; done
git -C "$ROOT" check-ignore -q "$RUNTIME/prefix/system.reg" || { printf 'Runtime must be Git-ignored\n' >&2; exit 1; }
python3 - "$SEED" "$RUNTIME" "$CD" "$DEVICE" <<'PY'
from pathlib import Path
import json,subprocess,sys
seed,out,cd,dev=map(Path,sys.argv[1:])
for p in (seed,out):
 for q in (p,*p.parents):
  if q.is_symlink():raise SystemExit('Refusing symlinked prefix/output path')
if seed == out or seed in out.parents or out in seed.parents:raise SystemExit('Overlapping paths')
mounts=json.loads(subprocess.check_output(['findmnt','--json','--mountpoint',str(cd),'-o','SOURCE,FSTYPE,OPTIONS']))['filesystems']
assert len(mounts)==1
m=mounts[0]
assert Path(m['source']).resolve()==dev.resolve() and m['fstype']=='iso9660' and 'ro' in m['options'].split(','), 'Wrong or writable CD mount'
label=subprocess.check_output(['lsblk','-ndo','LABEL',str(dev)],text=True).strip()
assert label=='DISC_4_SECRETWEAPONS','Wrong CD label'
assert (cd/'Setup.exe').is_file()
assert 'Secret Weapons of WWII' in (cd/'Setup.ini').read_text(errors='replace')
assert not (seed/'drive_c').is_symlink()
assert not (seed/'drive_c/Program Files/EA GAMES/Battlefield 1942/Mods/XPack2').exists(), 'Seed already contains expansion or community patch'
PY
# No kill: a busy seed blocks copying. Dedicated seed lock coordinates recipe use.
exec 8>"$(dirname "$SEED")/.sw-seed.lock"
flock -n 8
unset WINEARCH WINEDLLOVERRIDES WINEDLLPATH WINELOADER WINESERVER
WINEPREFIX="$SEED" timeout 10 "$SERVER" -w 8>&-
mkdir -p "$RUNTIME/logs"
exec 9>"$RUNTIME/.launch.lock"
flock -n 9
cp -a --reflink=auto "$SEED" "$RUNTIME/prefix"
export WINEPREFIX="$RUNTIME/prefix" WINESERVER="$SERVER" WINEDEBUG=-all
python3 - "$WINEPREFIX" "$CD" "$DEVICE" "$RUNTIME/logs/before-install.json" <<'PY'
from pathlib import Path
import hashlib,json,sys
p,cd,dev,manifest=map(Path,sys.argv[1:])
g=p/'drive_c/Program Files/EA GAMES/Battlefield 1942'
rows={str(f.relative_to(g)):hashlib.sha256(f.read_bytes()).hexdigest() for f in g.rglob('*') if f.is_file()}
manifest.write_text(json.dumps(rows,indent=2)+'\n')
for name,target in [('d:',cd),('d::',dev)]:
 link=p/'dosdevices'/name
 if link.is_symlink():link.unlink()
 elif link.exists():raise SystemExit('Unexpected real drive mapping')
 link.symlink_to(target)
PY
"$WINE" reg query 'HKCU\Software\Wine' /v Version 8>&- 9>&- >"$RUNTIME/logs/windows-version.log" 2>&1
"$SERVER" -w 8>&- 9>&-
cd "$CD"
printf 'Original Secret Weapons installer; separate prefix: %s\n' "$WINEPREFIX"
printf 'Enter any CD key only in the installer. Decline bundled DirectX and online registration.\n'
rc=0
"$WINE" 'D:\Setup.exe' 8>&- 9>&- >"$RUNTIME/logs/install.log" 2>&1 || rc=$?
"$SERVER" -w 8>&- 9>&-
printf 'Installer process exited %s; installation and gameplay still need verification.\n' "$rc"
exit "$rc"
