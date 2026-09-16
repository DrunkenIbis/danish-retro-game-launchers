#!/usr/bin/env bash
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd -- "$HERE/../.." && pwd)
RUNTIME=${MIDNIGHT_RUNTIME:-"$REPO/local/runtime/magnus-myggen-midnatsmysteriet-download"}
RUNNER=${MIDNIGHT_RUNNER:-"$REPO/local/cache/mm3-physical-cd/runner/lutris-GE-Proton7-43-x86_64"}
export WINEPREFIX="$RUNTIME/prefix-ge-xp"
export WINEARCH=win32
export WINEDLLOVERRIDES='mscoree,mshtml='
export LD_LIBRARY_PATH="$RUNNER/lib:$RUNNER/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
GAME="$WINEPREFIX/drive_c/Program Files/Magnus & Myggen - Midnatsmysteriet"
[[ -f "$GAME/mm13main.exe" && -x "$RUNNER/bin/wine" ]] || { printf 'Original installation or Wine runner missing.\n' >&2; exit 1; }
[[ -d "$RUNTIME/cdrom" ]] || { printf 'CD data missing.\n' >&2; exit 1; }
# Coordinate source use with the AppImage builder during its snapshot.
exec 9>"$RUNTIME/local-copy.lock"
flock -n 9 || { printf 'Game or AppImage build is already using this installation.\n' >&2; exit 1; }
cd -- "$GAME"
status=0
"$RUNNER/bin/wine" explorer /desktop=Midnatsmysteriet,800x600 'C:\Program Files\Magnus & Myggen - Midnatsmysteriet\mm13main.exe' || status=$?
"$RUNNER/bin/wineserver" -w
exit "$status"
