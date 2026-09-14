#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
ID=magnus-myggen-mysteriet-om-det-talende-solur
RUNTIME="${SOLUR_RUNTIME_DIR:-${RETRO_GAME_RUNTIME_DIR:-$REPO/local/runtime}/$ID}"
RUNTIME="$(realpath -m "$RUNTIME")"
MODE="${SOLUR_MODE:-game}"
GAME='Program Files/IVANOFF Interactive/Mysteriet om det talende solur'
if [[ "${SOLUR_DRY_RUN:-0}" == 1 ]]; then
    printf 'MODE=%s\nRUNTIME=%s\nEXE=%s/prefix/drive_c/%s/mm6.exe\n' "$MODE" "$RUNTIME" "$RUNTIME" "$GAME"
    exit 0
fi
[[ "$MODE" == game || "$MODE" == setup ]] || { printf 'SOLUR_MODE skal være game eller setup\n' >&2; exit 1; }
export WINEPREFIX="$RUNTIME/prefix" WINEARCH=win32
export WINEDEBUG="${WINEDEBUG:--all}" WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-mscoree,mshtml=}"
WINEBIN="${SOLUR_WINE_BIN:-wine32}"
if [[ "$WINEBIN" == */* ]]; then SERVER="$(dirname "$WINEBIN")/wineserver"; else SERVER=wineserver; fi
mkdir -p "$RUNTIME/logs"
if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
    timeout 90 "$WINEBIN" wineboot -u > "$RUNTIME/logs/wineboot.log" 2>&1 || {
        printf 'Wine-initialisering stoppede; se %s/logs/wineboot.log\n' "$RUNTIME" >&2
        exit 1
    }
fi
"$WINEBIN" reg add 'HKCU\Software\Wine' /v Version /d win98 /f >/dev/null
[[ -d "$RUNTIME/cdrom" ]] || { printf 'Kør install.sh --existing --no-launch først.\n' >&2; exit 1; }
ln -sfn "$RUNTIME/cdrom" "$WINEPREFIX/dosdevices/d:"
"$WINEBIN" reg add 'HKCU\Software\Wine\Drives' /v d: /d cdrom /f >/dev/null
exec 9>"$RUNTIME/.launch.lock"
flock -n 9 || { printf 'Solur kører allerede.\n' >&2; exit 1; }
if [[ "$MODE" == setup ]]; then
    cd "$RUNTIME/cdrom"
    EXE='D:\SETUP.EXE'
else
    [[ -f "$WINEPREFIX/drive_c/$GAME/mm6.exe" ]] || {
        printf 'Original installation mangler. Kør SOLUR_MODE=setup ./launch.sh\n' >&2; exit 1;
    }
    cd "$WINEPREFIX/drive_c/$GAME"
    EXE='C:\Program Files\IVANOFF Interactive\Mysteriet om det talende solur\mm6.exe'
fi
"$WINEBIN" explorer "/desktop=Solur,${SOLUR_DESKTOP_SIZE:-800x600}" "$EXE" "$@"
"$SERVER" -w
