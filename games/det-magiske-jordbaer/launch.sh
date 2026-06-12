#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GAME_ID="det-magiske-jordbaer"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
RUNTIME_DIR="${DMJ_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"

ISO="${DMJ_ISO:-$SOURCE_BASE/$GAME_ID/DetMagiskeJordbaer.iso}"
CDROM="${DMJ_CDROM:-$RUNTIME_DIR/cdrom}"
GAME="${DMJ_GAME_DIR:-$RUNTIME_DIR/game}"
CONF="${DMJ_CONF:-$RUNTIME_DIR/det-magiske-jordbaer.conf}"
LOGDIR="${DMJ_LOGDIR:-$RUNTIME_DIR/logs}"

mkdir -p "$CDROM" "$GAME" "$LOGDIR"

if [[ "${DMJ_DRY_RUN:-0}" == "1" ]]; then
  printf 'HERE=%s\nREPO_ROOT=%s\nISO=%s\nCDROM=%s\nGAME=%s\nCONF=%s\nLOGDIR=%s\n' \
    "$HERE" "$REPO_ROOT" "$ISO" "$CDROM" "$GAME" "$CONF" "$LOGDIR"
  exit 0
fi

if [ ! -f "$ISO" ]; then
  echo "ISO mangler: $ISO" >&2
  echo "Kør ./install.sh for at vælge mellem download fra reference-link eller import fra CD/DVD." >&2
  echo "Alternativt: placér din egen lovligt anskaffede ISO her, eller kør med DMJ_ISO=/sti/til/DetMagiskeJordbaer.iso" >&2
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

cat >"$CONF" <<EOF
[sdl]
fullscreen = false
windowresolution = 800x600
output = texture

[dosbox]
machine = svga_s3
memsize = 16

[cpu]
cpu_cycles = 12000

[mixer]
rate = 44100

[sblaster]
sbtype = sb16
sbbase = 220
irq = 7
dma = 1
hdma = 5

[autoexec]
@echo off
mount c "$GAME"
mount d "$CDROM" -t cdrom
c:
set dos4g=quiet
ADVENT -L0
exit
EOF

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
