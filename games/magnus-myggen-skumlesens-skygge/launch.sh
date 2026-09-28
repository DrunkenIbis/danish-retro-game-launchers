#!/usr/bin/env bash
# Canonical original-CD launcher for the user-verified local installation.
# All launch logic lives here; no installer or Lutris dependency.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(cd -- "$HERE/../.." && pwd)
RUNTIME="$ROOT/local/runtime/mm4-graphics"
RUNNER="$ROOT/local/runtime/mm4-thunk-fix/runner"
export WINEPREFIX="$RUNTIME/prefix" WINEARCH=win32
export WINESERVER="$RUNNER/bin/wineserver" WINELOADER="$RUNNER/bin/wine"
export LD_LIBRARY_PATH="$RUNNER/lib:$RUNNER/lib64"
export WINEDLLOVERRIDES='mscoree,mshtml=' WINEDEBUG=-all
CD_MOUNT=${MM4_CD_MOUNT:-/run/media/test/MM4DK}
CD_DEVICE=${MM4_CD_DEVICE:-/dev/sr0}
DESKTOP_ERRORS=0
[[ ${1:-} != --desktop ]] || { DESKTOP_ERRORS=1; shift; }
fail() {
    printf '%s\n' "$1" >&2
    if [[ $DESKTOP_ERRORS == 1 ]] && command -v notify-send >/dev/null; then
        notify-send -u critical 'Skumlesens Skygge' "$1" || true
    fi
    exit "${2:-2}"
}
[[ $# == 0 || ( $# == 1 && $1 == --check ) ]] || fail 'Brug: launch.sh [--desktop] [--check]'
[[ -x $WINELOADER && -x $WINESERVER && -f $WINEPREFIX/system.reg ]] || fail 'Den afprøvede lokale Wine-installation mangler. Se LOCAL_LAUNCHER.md.'
GAME="$WINEPREFIX/drive_c/Program Files/Skumlesens Skygge"
[[ -r $GAME/MM4.exe ]] || fail 'Den installerede MM4.exe mangler; der installeres ikke automatisk.'
[[ -r $CD_MOUNT/mm4.___ ]] || fail "Indsæt original-CD'en og åbn den i Filer, så den monteres på $CD_MOUNT." 3
[[ $(findmnt -rn --mountpoint "$CD_MOUNT" -o SOURCE) == "$CD_DEVICE" ]] || fail 'Original-CD er ikke monteret fra det forventede fysiske drev.' 3
[[ $(readlink -f "$WINEPREFIX/dosdevices/d:") == "$(readlink -f "$CD_MOUNT")" && $(readlink -f "$WINEPREFIX/dosdevices/d::") == "$(readlink -f "$CD_DEVICE")" ]] || fail 'CD-drevets mapping er ændret; den fungerende opsætning overskrives ikke.' 3
exec 9>"$RUNTIME/experiment.lock"
flock -n 9 || fail 'Spillet eller et forsøg kører allerede.' 4
timeout 3 "$WINESERVER" -w || fail 'Wine-prefixet er i brug. Luk den eksisterende kørsel først.' 4
# Only install cleanup after confirming that no pre-existing session is running.
cleanup() { "$WINESERVER" -k || true; timeout 15 "$WINESERVER" -w || true; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
version=$(timeout 30 "$WINELOADER" reg query 'HKCU\Software\Wine' /v Version) || fail 'Windows-kompatibiliteten kunne ikke aflæses.'
[[ $version == *REG_SZ*winxp* ]] || fail 'Den afprøvede Windows XP-indstilling er ændret; ingen automatisk rettelse.'
mem=$(timeout 30 "$WINELOADER" reg query 'HKLM\Software\IVANOFF Interactive\MM4' /v UseSystemMemory) || fail 'Grafikindstillingen kunne ikke aflæses.'
[[ $mem =~ (^|[[:space:]])UseSystemMemory[[:blank:]]+REG_DWORD[[:blank:]]+0x0+[[:space:]]*$ ]] || fail 'UseSystemMemory skal være 0 som i den afprøvede opsætning.'
[[ ${1:-} != --check ]] || { printf 'Klar: original-CD, XP og UseSystemMemory=0 er kontrolleret.\n'; exit 0; }
cd -- "$GAME"
printf 'Starter Skumlesens Skygge med original-CD. Ingen test-timer.\n'
rc=0
"$WINELOADER" explorer /desktop=MM4GFX,1024x768 'C:\Program Files\Skumlesens Skygge\MM4.exe' || rc=$?
[[ $rc == 0 ]] || fail "Wine afsluttede med kode $rc." "$rc"
