#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO="${PYRUS_ISO:-$HERE/Pyrus.iso}"
CDROM="${PYRUS_CDROM:-$HERE/cdrom}"
PREFIX="${WINEPREFIX:-$HERE/wineprefix32}"
WINEBIN="${PYRUS_WINE:-$(command -v wine32 || command -v wine)}"
MODE="${PYRUS_MODE:-loader}"
DESKTOP="${PYRUS_DESKTOP:-Pyrus,800x600}"
LOCK="$HERE/.pyrus.lock"
case "$MODE" in
  loader) TARGET='D:\Loader.exe' ;;
  pyrus) TARGET='D:\Pyrus.exe' ;;
  viewer) TARGET='D:\Viewer\PyrusView.exe' ;;
  paint) TARGET='D:\Paint\Paint.exe' ;;
  puzzle) TARGET='D:\Puzzle\Puzzle.exe' ;;
  quiz) TARGET='D:\Quiz\Quiz.exe' ;;
  setup) TARGET='D:\Setup.exe' ;;
  *) TARGET="$MODE" ;;
esac
if [[ "${PYRUS_DRY_RUN:-0}" == "1" ]]; then
  printf 'HERE=%s\nISO=%s\nCDROM=%s\nPREFIX=%s\nWINEBIN=%s\nMODE=%s\nTARGET=%s\nDESKTOP=%s\n' "$HERE" "$ISO" "$CDROM" "$PREFIX" "$WINEBIN" "$MODE" "$TARGET" "$DESKTOP"
  exit 0
fi
[[ -f "$ISO" ]] || { echo "Missing ISO: $ISO" >&2; exit 2; }
if [[ ! -f "$CDROM/Loader.exe" || ! -f "$CDROM/Pyrus.exe" ]]; then
  mkdir -p "$CDROM"
  7z x -y -o"$CDROM" "$ISO" >/dev/null
fi
printf 'PYRUS\n' > "$CDROM/.windows-label"
mkdir -p "$(dirname "$PREFIX")"
export WINEPREFIX="$PREFIX"
if [[ ! -d "$PREFIX/drive_c/windows" ]]; then
  export WINEARCH="${WINEARCH:-win32}"
fi
mkdir -p "$PREFIX/dosdevices"
ln -sfn "$CDROM" "$PREFIX/dosdevices/d:"
ln -sfn "$CDROM/.windows-label" "$PREFIX/dosdevices/d::"
export WINEDLLOVERRIDES="${WINEDLLOVERRIDES:-ddraw,dinput,dsound=n,b}"
export WINEDEBUG="${WINEDEBUG:--all}"
exec "$WINEBIN" explorer /desktop="$DESKTOP" "$TARGET"
