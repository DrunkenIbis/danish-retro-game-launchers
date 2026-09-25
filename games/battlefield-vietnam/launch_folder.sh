#!/usr/bin/env bash
# Diagnostic folder-only route; never edits the physical-CD prefix.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
RUNTIME="${BFV_FOLDER_RUNTIME:-$(retro_runtime_dir "$ROOT" battlefield-vietnam)/folder-ge7}"
WINE="${BFV_WINE:-$ROOT/local/runners/lutris-GE-Proton7-43-x86_64/bin/wine}"
SERVER="$(dirname "$WINE")/wineserver"
[[ "$RUNTIME" == /* && "$WINE" == /* ]]
# Resolve runtime and prefix aliases before any Wine call, lock or log creation.
# Protect resolved runtimes AND external prefix targets, including ancestors.
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
[[ -x "$WINE" && -x "$SERVER" ]]
unset WINEARCH WINEDLLOVERRIDES WINEDLLPATH
export WINEPREFIX="$RUNTIME/prefix" WINEDEBUG=-all
[[ -f "$WINEPREFIX/system.reg" ]] || { printf 'Prepare a stopped installed prefix copy in %s first.\n' "$WINEPREFIX" >&2; exit 1; }
mkdir -p "$RUNTIME/logs"
exec 9>"$RUNTIME/.lock"
flock -n 9
# Refuse to modify a live prefix or the known physical/gameplay-preserved prefix.
timeout 5 "$SERVER" -w 9>&-
python3 - "$WINEPREFIX" "$(retro_runtime_dir "$ROOT" battlefield-vietnam)/physical-ge7" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1]).resolve(); protected=Path(sys.argv[2]).resolve()
if p==protected or protected in p.parents:sys.exit('Refusing physical/preserved prefix')
for link in (p/'dosdevices').iterdir():
 if link.name not in ('c:','z:') and link.is_symlink():link.unlink()
PY
EXE="$(python3 - "$WINEPREFIX/drive_c" <<'PY'
from pathlib import Path
import sys
hits=[p for p in Path(sys.argv[1]).rglob('*') if p.is_file() and p.name.lower()=='bfvietnam.exe']
if len(hits)!=1:sys.exit('Missing/ambiguous installed bfvietnam.exe')
print(hits[0])
PY
)"
cd "$(dirname "$EXE")"
rc=0
"$WINE" "$EXE" 9>&- >"$RUNTIME/logs/game-$(date +%Y%m%d-%H%M%S).log" 2>&1 || rc=$?
"$SERVER" -w 9>&- || rc=$?
exit "$rc"
