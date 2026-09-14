#!/usr/bin/env bash
# Launch the preserved original installation using local CD data only.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)
RUNTIME=${MM3_LOCAL_RUNTIME:-$ROOT/local/runtime/mm3-local-copy}
WINE=${MM3_LOCAL_WINE:-$ROOT/local/cache/mm3-physical-cd/runner/lutris-GE-Proton7-43-x86_64/bin/wine}
MODE=${1:-game}
fail() { printf 'MM3 local copy: %s\n' "$*" >&2; exit 1; }
[[ $# -le 1 ]] || fail 'Usage: local_copy.sh {game|kill|dry-run}'
case $MODE in game|kill|dry-run) ;; *) fail "Unknown mode: $MODE" ;; esac
if [[ $MODE == dry-run ]]; then
    printf 'Runtime: %s\nWine: %s\nMedia: local cdrom directory; no physical device required.\n' "$RUNTIME" "$WINE"
    exit 0
fi
RUNTIME=$(realpath -e -- "$RUNTIME")
WINE=$(realpath -e -- "$WINE")
SERVER=$(dirname -- "$WINE")/wineserver
PREFIX=$RUNTIME/prefix-ge
[[ -x $WINE && -x $SERVER ]] || fail 'Verified Wine-GE runner is missing.'
[[ ! -L $PREFIX && -f $PREFIX/system.reg && -d $PREFIX/dosdevices && ! -L $PREFIX/dosdevices ]] || fail 'Missing or unsafe copied prefix; see README preparation instructions.'
export WINEPREFIX=$PREFIX WINEARCH=win32 WINEDEBUG=${WINEDEBUG:--all}
export WINEDLLOVERRIDES=${WINEDLLOVERRIDES:-mscoree,mshtml=}
if [[ $MODE == kill ]]; then
    "$SERVER" -k
    "$SERVER" -w
    exit 0
fi
[[ -d $RUNTIME/cdrom && ! -L $RUNTIME/cdrom ]] || fail 'Local CD data directory missing or symlinked.'
mapfile -d '' -t games < <(find "$PREFIX/drive_c/Program Files" -type f -iname mm3run.exe -print0 && printf '\0')
[[ ${#games[@]} -gt 0 && ${games[-1]} == '' ]] || fail 'Could not scan installed game.'
unset 'games[-1]'
[[ ${#games[@]} == 1 ]] || fail 'Expected exactly one original installed mm3run.exe.'
exec 9>"$RUNTIME/local-copy.lock"
flock -n 9 || fail 'Local copy is already running.'
# Remove stale physical drive mappings in this copy only, not the working CD prefix.
for name in d: d:: e: e::; do
    path=$PREFIX/dosdevices/$name
    [[ ! -e $path || -L $path ]] || fail "Refusing to replace non-symlink $path"
done
for name in d: d:: e: e::; do
    path=$PREFIX/dosdevices/$name
    [[ ! -L $path ]] || unlink -- "$path"
done
ln -s -- "$RUNTIME/cdrom" "$PREFIX/dosdevices/e:"
CHILD=
stop() {
    trap '' INT TERM HUP
    "$SERVER" -k || true
    if [[ -n $CHILD ]]; then
        kill -TERM "$CHILD" 2>/dev/null || true
        wait "$CHILD" 2>/dev/null || true
    fi
    "$SERVER" -w || true
    exit "$1"
}
trap 'stop 130' INT
trap 'stop 143' TERM
trap 'stop 129' HUP
cd -- "$(dirname -- "${games[0]}")"
status=0
"$WINE" "${games[0]}" 9>&- &
CHILD=$!
wait "$CHILD" || status=$?
"$SERVER" -w 9>&- &
CHILD=$!
wait "$CHILD" || { wait_status=$?; [[ $status != 0 ]] || status=$wait_status; }
exit "$status"
