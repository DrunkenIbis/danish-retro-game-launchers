#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WINE_BIN="${HARRY_WINE:-$BASE_DIR/runners/wine-ge-8-26/bin/wine}"
WINESERVER_BIN="${HARRY_WINESERVER:-$BASE_DIR/runners/wine-ge-8-26/bin/wineserver}"
export WINEPREFIX="${HARRY_WINEPREFIX:-$BASE_DIR/wineprefix_ge}"
export WINEDEBUG="${WINEDEBUG:--all}"
DESKTOP_SIZE="${HARRY_DESKTOP_SIZE:-800x600}"
# Allow both `HARRY_MODE=kill ./launch-harry.sh` and `./launch-harry.sh kill`.
MODE="${1:-${HARRY_MODE:-game}}"

CDROM_DIR="$BASE_DIR/cdrom"
GAME_DIR="$WINEPREFIX/drive_c/Harry"

if [[ ! -x "$WINE_BIN" ]]; then
  echo "Wine GE runner mangler: $WINE_BIN" >&2
  exit 1
fi
if [[ ! -d "$CDROM_DIR" ]]; then
  echo "CD-ROM mappe mangler: $CDROM_DIR" >&2
  exit 1
fi
if [[ ! -x "$GAME_DIR/harry.exe" ]]; then
  echo "Installeret Harry mangler: $GAME_DIR/harry.exe" >&2
  echo "Kør evt. først: HARRY_MODE=cdmenu $0 og vælg Installer Spillet" >&2
  exit 1
fi

# Vigtig detalje for dette spil:
# CD-checken virker først når D: er en almindelig Wine drive med label HARRY.
# Hvis HKCU\Software\Wine\Drives d:=cdrom eller d:: bruges, ser spillet stadig ikke CD'en korrekt.
mkdir -p "$WINEPREFIX/dosdevices"
ln -sfn "$CDROM_DIR" "$WINEPREFIX/dosdevices/d:"
rm -f "$WINEPREFIX/dosdevices/d::"
printf 'HARRY\n' > "$CDROM_DIR/.windows-label"
"$WINE_BIN" reg delete 'HKCU\Software\Wine\Drives' /v 'd:' /f >/dev/null 2>&1 || true
"$WINE_BIN" reg add 'HKCU\Software\Wine' /v Version /t REG_SZ /d win98 /f >/dev/null 2>&1 || true

case "$MODE" in
  game|installed)
    cd "$GAME_DIR"
    exec "$WINE_BIN" explorer "/desktop=Harry,$DESKTOP_SIZE" 'C:\Harry\harry.exe'
    ;;
  cdmenu|menu)
    cd "$CDROM_DIR"
    exec "$WINE_BIN" explorer "/desktop=Harry,$DESKTOP_SIZE" 'D:\CDmenu.exe'
    ;;
  setup|install)
    cd "$CDROM_DIR"
    exec "$WINE_BIN" explorer "/desktop=Harry,$DESKTOP_SIZE" 'D:\setup.exe'
    ;;
  kill)
    exec "$WINESERVER_BIN" -k
    ;;
  *)
    echo "Ukendt HARRY_MODE=$MODE; brug game, cdmenu, setup eller kill" >&2
    exit 2
    ;;
esac
