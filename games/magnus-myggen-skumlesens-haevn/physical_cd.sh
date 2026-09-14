#!/usr/bin/env bash
# Original physical-CD path; original installation/gameplay user-confirmed.
# Usage: physical_cd.sh {setup|game|kill|dry-run}
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
CD=${MM3_PHYSICAL_CD:-/run/media/test/M322DK}
DEVICE=${MM3_PHYSICAL_DEVICE:-/dev/sr0}
RUNTIME=${MM3_PHYSICAL_RUNTIME:-$ROOT/local/runtime/mm3-physical-cd}
WINE=${MM3_PHYSICAL_WINE:-$ROOT/local/cache/mm3-physical-cd/runner/lutris-GE-Proton7-43-x86_64/bin/wine}
PREFIX=$RUNTIME/prefix-ge
SERVER=$(dirname -- "$WINE")/wineserver
MODE=${1:-game}
fail() { printf 'physical_cd: %s\n' "$*" >&2; exit 1; }
[[ $# -le 1 ]] || fail 'Usage: physical_cd.sh {setup|game|kill|dry-run}'
case $MODE in setup|game|kill|dry-run) ;; *) fail "Unknown mode: $MODE" ;; esac
if [[ $MODE == dry-run ]]; then
    printf 'CD: %s\nDevice: %s\nPrefix: %s\nWine: %s\nWineserver: %s\n' "$CD" "$DEVICE" "$PREFIX" "$WINE" "$SERVER"
    printf 'Plan only: validate physical mount; original setup or installed mm3run.exe. No changes.\nOriginal physical-CD installation/gameplay user-confirmed; this is only a dry run.\n'
    exit 0
fi
# Resolve paths before changing cwd; no mutation until every preflight passes.
RUNTIME=$(realpath -m -- "$RUNTIME")
PREFIX=$RUNTIME/prefix-ge
WINE=$(realpath -m -- "$WINE")
SERVER=$(dirname -- "$WINE")/wineserver
[[ -x $WINE && -x $SERVER ]] || fail 'Selected Wine and its sibling wineserver must already exist and be executable (no downloads).'
export WINEPREFIX=$PREFIX WINEARCH=win32
export WINEDEBUG=${WINEDEBUG:--all}
export WINEDLLOVERRIDES=${WINEDLLOVERRIDES:-mscoree,mshtml=}
if [[ $MODE == kill ]]; then
    [[ -d $PREFIX ]] || exit 0
    status=0
    "$SERVER" -k || status=$?
    "$SERVER" -w || { wait_status=$?; [[ $status != 0 ]] || status=$wait_status; }
    exit "$status"
fi
CD=$(realpath -e -- "$CD") || fail 'CD directory is missing.'
[[ -d $CD && -r $CD && -x $CD ]] || fail 'CD directory must be readable.'
DEVICE=$(realpath -e -- "$DEVICE") || fail 'Physical device is missing.'
[[ -r $DEVICE ]] || fail 'Physical device is not readable; arrange read access outside this script.'
[[ $(LC_ALL=C stat -Lc '%F' -- "$DEVICE") == 'block special file' ]] || fail 'Physical device is not a block device.'
SOURCE=$(findmnt --noheadings --raw --output SOURCE --mountpoint "$CD") || fail 'CD path is not an actual mountpoint.'
[[ -n $SOURCE && $SOURCE != *$'\n'* ]] || fail 'Expected exactly one mount source.'
SOURCE=$(realpath -e -- "$SOURCE") || fail 'Mount source is not a physical device path.'
[[ $SOURCE == "$DEVICE" ]] || fail 'CD mount source does not match physical device.'
case $RUNTIME/ in "$CD/"*) fail 'Runtime must not be inside CD media.' ;; esac
[[ ! -L $PREFIX ]] || fail 'Refusing a symlinked prefix.'
if [[ -e $PREFIX ]]; then
    [[ -d $PREFIX/dosdevices && ! -L $PREFIX/dosdevices && -d $PREFIX/drive_c && ! -L $PREFIX/drive_c && -f $PREFIX/system.reg && ! -L $PREFIX/system.reg ]] || fail 'Incomplete or symlinked prefix; inspect it manually (not reinitialized).'
fi
# Empty final record is a success sentinel: never accept partial find output.
mapfile -d '' -t setups < <(find "$CD" -maxdepth 1 -type f -iname setup.exe -print0 && printf '\0')
[[ ${#setups[@]} -gt 0 && ${setups[-1]} == '' ]] || fail 'Could not scan CD root.'
unset 'setups[-1]'
[[ ${#setups[@]} == 1 ]] || fail 'Expected exactly one setup.exe at CD root.'
[[ -r ${setups[0]} ]] || fail 'CD setup.exe is not readable.'
TARGET=${setups[0]}
if [[ $MODE == game ]]; then
    [[ -d $PREFIX/drive_c/'Program Files' ]] || fail 'Game is not installed; run setup and complete the original wizard first.'
    mapfile -d '' -t games < <(find "$PREFIX/drive_c/Program Files" -type f -iname mm3run.exe -print0 && printf '\0')
    [[ ${#games[@]} -gt 0 && ${games[-1]} == '' ]] || fail 'Could not completely scan Program Files.'
    unset 'games[-1]'
    [[ ${#games[@]} == 1 ]] || fail 'Expected exactly one installed mm3run.exe under Program Files; missing or ambiguous installation.'
    TARGET=${games[0]}
    [[ -r $TARGET ]] || fail 'Installed mm3run.exe is not readable.'
fi
# Background + shell wait makes INT/TERM/HUP responsive even when Wine blocks.
CHILD=
run_child() {
    local status=0
    "$@" &
    CHILD=$!
    wait "$CHILD" || status=$?
    CHILD=
    return "$status"
}
stop() {
    local status=$1
    trap '' INT TERM HUP
    trap - EXIT
    "$SERVER" -k || true
    if [[ -n $CHILD ]]; then
        kill -TERM "$CHILD" 2>/dev/null || true
        wait "$CHILD" 2>/dev/null || true
    fi
    "$SERVER" -w || true
    exit "$status"
}
trap 'stop 130' INT
trap 'stop 143' TERM
trap 'stop 129' HUP
# A failed bootstrap can leave Wine children behind. Keep this path bounded.
if [[ ! -e $PREFIX && ! -L $PREFIX ]]; then
    mkdir -p -- "$RUNTIME"
    boot_status=0
    run_child timeout --signal=TERM --kill-after=10s 90s "$WINE" wineboot --init || boot_status=$?
    if [[ $boot_status != 0 ]]; then
        "$SERVER" -k || true
        timeout --signal=TERM --kill-after=10s 10s "$SERVER" -w || true
        exit "$boot_status"
    fi
fi
# Always wait for the paired server, including nonzero launcher/reg exits.
finish() {
    local status=$? wait_status=0
    trap - EXIT
    run_child "$SERVER" -w || wait_status=$?
    [[ $status != 0 ]] || status=$wait_status
    exit "$status"
}
trap finish EXIT
[[ -d $PREFIX/dosdevices && -d $PREFIX/drive_c && -f $PREFIX/system.reg ]] || fail 'Incomplete prefix; inspect it manually (not reinitialized).'
run_child "$WINE" reg add 'HKCU\Software\Wine' /v Version /t REG_SZ /d win98 /f
run_child "$WINE" reg add 'HKLM\Software\Microsoft\Windows\CurrentVersion' /v CommonFilesDir /t REG_SZ /d 'C:\Program Files\Common Files' /f
run_child "$WINE" reg add 'HKLM\Software\Microsoft\Windows\CurrentVersion' /v ProgramFilesDir /t REG_SZ /d 'C:\Program Files' /f
ln -sfnT -- "$CD" "$PREFIX/dosdevices/e:"
ln -sfnT -- "$DEVICE" "$PREFIX/dosdevices/e::"
run_child "$WINE" reg add 'HKCU\Software\Wine\Drives' /v 'e:' /t REG_SZ /d cdrom /f
cd -- "$(dirname -- "$TARGET")"
run_child "$WINE" "$TARGET"
