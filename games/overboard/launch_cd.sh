#!/usr/bin/env bash
# Original physical CD + original installed state; independent of image experiments.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
RUNTIME="${OVERBOARD_PHYSICAL_RUNTIME:-$ROOT/local/runtime/overboard-physical}"
PREFIX="${OVERBOARD_PHYSICAL_PREFIX:-$RUNTIME/wineprefix-ge}"
WINE="${OVERBOARD_PHYSICAL_WINE:-$ROOT/local/runners/lutris-GE-Proton7-43-x86_64/bin/wine}"
SERVER="$(dirname "$WINE")/wineserver"
CD="${OVERBOARD_CD_MOUNT:-/run/media/$USER/OVERBOARD}"
DEVICE="${OVERBOARD_CD_DEVICE:-/dev/sr0}"
MODE="${1:-game}"
EXE="$PREFIX/drive_c/Program Files/Psygnosis/Overboard!/Ob.exe"
fail() { printf 'Overboard CD: %s\n' "$*" >&2; exit 1; }
case "$MODE" in game|--check|--dry-run) ;; *) fail 'Brug game, --check eller --dry-run';; esac
if [[ "$MODE" == --dry-run ]]; then
    printf 'PREFIX=%s\nWINE=%s\nCD=%s\nDEVICE=%s\nEXE=%s\n' "$PREFIX" "$WINE" "$CD" "$DEVICE" "$EXE"
    exit 0
fi
[[ -b "$DEVICE" && -r "$DEVICE" ]] || fail "Cd-drevet er ikke læsbart: $DEVICE"
source="$(findmnt -rn -o SOURCE --mountpoint "$CD")" || fail "Cd'en er ikke monteret: $CD"
[[ "$(readlink -f "$source")" == "$(readlink -f "$DEVICE")" ]] || fail 'Mountpoint og fysisk cd-drev stemmer ikke overens'
[[ -r "$CD/ob.exe" && -r "$CD/res.rda" && -r "$CD/intro.mpx" ]] || fail 'Den forventede Overboard-cd mangler'
[[ -x "$WINE" && -x "$SERVER" ]] || fail "Wine-GE runner mangler: $WINE"
[[ -f "$PREFIX/system.reg" && -f "$EXE" ]] || fail "Original installation mangler i $PREFIX; se README.md"
if [[ "$MODE" == --check ]]; then
    printf 'OK: fysisk cd, runner og installeret spil fundet. Ingen ændringer udført.\n'
    exit 0
fi
mkdir -p "$RUNTIME/logs"
exec 9>"$RUNTIME/.physical-launch.lock"
flock -n 9 || fail 'Denne launcher kører allerede'
export WINEPREFIX="$PREFIX"
unset WINEARCH
export WINEDEBUG="${OVERBOARD_PHYSICAL_DEBUG:--all}"
# Replace only prefix links, never write labels or extracted data to the CD.
rm -f "$PREFIX/dosdevices/d:" "$PREFIX/dosdevices/d::"
ln -s "$CD" "$PREFIX/dosdevices/d:"
ln -s "$DEVICE" "$PREFIX/dosdevices/d::"
"$WINE" reg add 'HKCU\Software\Wine\Drives' /v d: /d cdrom /f >/dev/null
"$WINE" reg add 'HKCU\Software\Wine' /v Version /d win98 /f >/dev/null
printf 'Starter Overboard fra original installation. Tryk Esc ved sort intro.\n'
# Keep the same working directory and Explorer invocation as the confirmed run.
cd "$RUNTIME"
status=0
"$WINE" explorer /desktop=Overboard,800x600 'C:\Program Files\Psygnosis\Overboard!\Ob.exe' >"$RUNTIME/logs/launch-cd.log" 2>&1 || status=$?
"$SERVER" -w || true
exit "$status"
