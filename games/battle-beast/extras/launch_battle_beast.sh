#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO="$BASE_DIR/BEAST.iso"
INSTALL_DIR="$BASE_DIR/battle-beast-extracted"
WINEPREFIX="${WINEPREFIX:-$BASE_DIR/wineprefix32}"
WINEARCH="${BB_WINEARCH:-win32}"
WINE_BIN="${BB_WINE_BIN:-wine32}"

export WINEPREFIX WINEARCH

if ! command -v 7z >/dev/null 2>&1; then
  echo "Fejl: 7z er ikke installeret."
  exit 1
fi

if ! command -v "$WINE_BIN" >/dev/null 2>&1; then
  echo "Fejl: $WINE_BIN er ikke installeret."
  exit 1
fi

if [ ! -f "$ISO" ]; then
  echo "Fejl: ISO-filen blev ikke fundet: $ISO"
  exit 1
fi

# Extract ISO once, then reuse the extracted files on later launches.
if [ ! -f "$INSTALL_DIR/WIN95/LAUNCH.EXE" ]; then
  mkdir -p "$INSTALL_DIR"
  echo "Udpakker ISO til: $INSTALL_DIR"
  7z x -y "-o$INSTALL_DIR" "$ISO" >/dev/null
fi

if [ ! -d "$WINEPREFIX" ] || [ ! -f "$WINEPREFIX/system.reg" ]; then
  echo "Opretter Wine-prefix: $WINEPREFIX"
  mkdir -p "$WINEPREFIX"
fi

cd "$INSTALL_DIR"
exec "$WINE_BIN" "$INSTALL_DIR/WIN95/LAUNCH.EXE"
