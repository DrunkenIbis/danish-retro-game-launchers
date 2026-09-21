#!/usr/bin/env bash
# Original Q112DK installation only; never reuse the CAB-only Q122DK runtime.
set -Eeuo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNTIME="${MMQ_PHYSICAL_RUNTIME:-$ROOT/local/runtime/magnus-myggen-quizkampen-superstarter/physical-q112dk-ge}"
PREFIX="$RUNTIME/wineprefix32"
RUNNER="${MMQ_PHYSICAL_RUNNER:-$ROOT/local/runners/lutris-GE-Proton7-43-x86_64}"
CD="${MMQ_PHYSICAL_CD:-/run/media/$USER/Q112DK}"
DEVICE="${MMQ_PHYSICAL_DEVICE:-/dev/sr0}"
MODE="${1:-game}"
fail() { printf 'Quizkampen: %s\n' "$*" >&2; exit 1; }
case "$MODE" in
  dry-run)
    printf 'Original CD: Q112DK (%s, %s)\nPrefix: %s\nRunner: %s\nWindow: 800x600\n' "$CD" "$DEVICE" "$PREFIX" "$RUNNER"
    exit 0 ;;
  game) ;;
  *) fail 'Brug game eller dry-run.' ;;
esac
[[ -x "$RUNNER/bin/wine" && -x "$RUNNER/bin/wineserver" ]] || fail "Wine-GE mangler: $RUNNER"
[[ -f "$PREFIX/system.reg" ]] || fail 'Originalinstallationen mangler. Se PHYSICAL_CD.md.'
[[ -b "$DEVICE" && -r "$DEVICE" ]] || fail "CD-enheden kan ikke læses: $DEVICE"
SOURCE="$(findmnt -rn --mountpoint "$CD" -o SOURCE)" || fail "CD er ikke monteret: $CD"
[[ "$(readlink -f "$SOURCE")" == "$(readlink -f "$DEVICE")" ]] || fail 'Mountpoint og CD-enhed matcher ikke.'
[[ "$(lsblk -dnro LABEL "$DEVICE")" == Q112DK ]] || fail 'Forventede den originale Q112DK-CD.'
# Mapping is established by the original installation; reject stale mappings.
[[ "$(readlink -f "$PREFIX/dosdevices/d:")" == "$(readlink -f "$CD")" ]] || fail 'Wine D: peger ikke på den originale CD.'
[[ "$(readlink -f "$PREFIX/dosdevices/d::")" == "$(readlink -f "$DEVICE")" ]] || fail 'Wine D:: peger ikke på CD-enheden.'
GAME="$PREFIX/drive_c/Program Files/Magnus & Myggen - Quizkampen"
[[ -f "$GAME/mm12main.EXE" ]] || fail "Det installerede spil mangler: $GAME/mm12main.EXE"
export WINEPREFIX="$PREFIX" WINEARCH=win32 WINEDEBUG=-all WINEDLLOVERRIDES='mscoree,mshtml='
mkdir -p "$RUNTIME/logs"
exec 9>"$RUNTIME/.physical-launch.lock"
flock -n 9 || fail 'Denne launcher kører allerede.'
cd "$GAME"
# Do not exec Explorer: it may detach before the game exits.
status=0
"$RUNNER/bin/wine" explorer /desktop=Quizkampen,800x600 'C:\Program Files\Magnus & Myggen - Quizkampen\mm12main.EXE' >"$RUNTIME/logs/physical-launch.log" 2>&1 || status=$?
wait_status=0
"$RUNNER/bin/wineserver" -w || wait_status=$?
if [[ "$status" == 0 ]]; then status=$wait_status; fi
exit "$status"
