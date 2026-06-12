#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

ISO="${DMJ_ISO:-$HERE/DetMagiskeJordbaer.iso}"
CDROM="$HERE/cdrom"
GAME="$HERE/game"
CONF="$HERE/det-magiske-jordbaer.conf"
LOGDIR="$HERE/logs"
mkdir -p "$CDROM" "$GAME" "$LOGDIR"

if [ ! -f "$ISO" ]; then
  echo "ISO mangler: $ISO" >&2
  exit 1
fi

if [ ! -f "$CDROM/ADVENT.EXE" ]; then
  if ! command -v 7z >/dev/null 2>&1; then
    echo "7z mangler; kan ikke udpakke ISO til $CDROM" >&2
    exit 1
  fi
  7z x -y -o"$CDROM" "$ISO" >"$LOGDIR/extract.log"
fi

# Minimal lokal install-tree. ADVENT.RES bliver liggende på CD-ROM-mountet (D:),
# mens de små runtime-filer køres fra den skrivbare C:-mappe.
for f in EGAVGA.BGI DETECT.EXE DOS4GW.EXE WINRUN.EXE STRMGC.ICN STRMGC.SND ADVENT.EXE ERRORS.BIN SETSOUND.EXE ADVENT.INI ADVENT.000 ADVENT.RTS GLOBAL.SET STR.ID; do
  if [ -f "$CDROM/$f" ]; then
    cp -f "$CDROM/$f" "$GAME/$f"
  fi
done

if [ ! -f "$GAME/ADVENT.EXE" ]; then
  echo "ADVENT.EXE mangler efter udpakning/kopiering" >&2
  exit 1
fi

if command -v dosbox-staging >/dev/null 2>&1; then
  exec dosbox-staging -conf "$CONF" -noconsole
elif command -v dosbox >/dev/null 2>&1; then
  exec dosbox -conf "$CONF" -noconsole
elif command -v flatpak >/dev/null 2>&1 && flatpak info io.github.dosbox-staging >/dev/null 2>&1; then
  exec flatpak run io.github.dosbox-staging -conf "$CONF" -noconsole
else
  echo "Ingen DOSBox fundet. Installer dosbox-staging/dosbox, eller Flatpak appen io.github.dosbox-staging." >&2
  exit 1
fi
