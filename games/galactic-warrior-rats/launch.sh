#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GAME_ID="galactic-warrior-rats"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${GWR_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${GWR_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ARCHIVE="${GWR_ARCHIVE:-$SOURCE_DIR/003318_galactic_warrior_rats.7z}"
EXTRACT_DIR="$SOURCE_DIR/archive-extracted"
DISK_IMG="$EXTRACT_DIR/003318_galactic_warrior_rats/disk1.img"
GAME_DIR="$RUNTIME_DIR/game"
CONF_TEMPLATE="$HERE/dosbox.conf"
CONF="$RUNTIME_DIR/galactic-warrior-rats.conf"
LOGDIR="$RUNTIME_DIR/logs"

mkdir -p "$GAME_DIR" "$LOGDIR"

if [[ "${GWR_DRY_RUN:-0}" == "1" ]]; then
  printf 'HERE=%s\nREPO_ROOT=%s\nARCHIVE=%s\nDISK_IMG=%s\nGAME_DIR=%s\nCONF=%s\nLOGDIR=%s\n' \
    "$HERE" "$REPO_ROOT" "$ARCHIVE" "$DISK_IMG" "$GAME_DIR" "$CONF" "$LOGDIR"
  exit 0
fi

if [[ ! -f "$GAME_DIR/GWR.COM" || ! -f "$GAME_DIR/GWR.EXE" ]]; then
  if [[ ! -f "$ARCHIVE" ]]; then
    echo "7z-arkiv mangler: $ARCHIVE" >&2
    echo "Kør ./install.sh --download --no-launch, eller placér arkivet i local/sources/$GAME_ID/." >&2
    exit 1
  fi
  if ! command -v 7z >/dev/null 2>&1; then
    echo "7z mangler; kan ikke udpakke arkivet/floppy-image." >&2
    exit 1
  fi
  mkdir -p "$EXTRACT_DIR" "$GAME_DIR"
  if [[ ! -f "$DISK_IMG" ]]; then
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    7z x -y -o"$EXTRACT_DIR" "$ARCHIVE" >"$LOGDIR/extract-archive.log"
  fi
  [[ -f "$DISK_IMG" ]] || { echo "disk1.img mangler efter udpakning: $DISK_IMG" >&2; exit 1; }
  rm -rf "$GAME_DIR"
  mkdir -p "$GAME_DIR"
  7z x -y -o"$GAME_DIR" "$DISK_IMG" >"$LOGDIR/extract-disk.log"
fi

for required in GWR.COM GWR.EXE LEVSP.BIN ALSP1.BIN ALSP2.BIN PATS1 PATS2 GAMEON.PCM GAMEOVER.PCM GWRTITLE.PCM; do
  [[ -f "$GAME_DIR/$required" ]] || { echo "Runtime mangler $required i $GAME_DIR" >&2; exit 1; }
done

[[ -f "$CONF_TEMPLATE" ]] || { echo "DOSBox template mangler: $CONF_TEMPLATE" >&2; exit 1; }
python3 - "$CONF_TEMPLATE" "$CONF" "$GAME_DIR" <<'PY'
from pathlib import Path
import sys
src, dst, game_dir = map(Path, sys.argv[1:])
text = src.read_text(encoding='utf-8')
text = text.replace('@GAME_DIR@', str(game_dir))
dst.parent.mkdir(parents=True, exist_ok=True)
dst.write_text(text, encoding='utf-8')
PY

if [[ -n "${GWR_DOSBOX_BIN:-}" ]]; then
  exec ${GWR_DOSBOX_BIN} -conf "$CONF" -noprimaryconf
elif command -v dosbox-staging >/dev/null 2>&1; then
  exec dosbox-staging -conf "$CONF" -noprimaryconf
elif command -v dosbox >/dev/null 2>&1; then
  exec dosbox -conf "$CONF" -noprimaryconf
elif command -v flatpak >/dev/null 2>&1 && flatpak info io.github.dosbox-staging >/dev/null 2>&1; then
  exec flatpak run io.github.dosbox-staging -conf "$CONF" -noprimaryconf
else
  echo "Ingen DOSBox fundet. Installer dosbox-staging/dosbox, eller Flatpak appen io.github.dosbox-staging." >&2
  exit 1
fi
