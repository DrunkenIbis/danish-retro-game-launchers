#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="magnus-myggen-skumlesens-haevn"
GAME_TITLE="Magnus & Myggen: Skumlesens Hævn"

INSTALLER_DOWNLOAD_LABEL="archive.org BIN/CUE reference-linket"
INSTALLER_ISO_NAME="M322DK.iso"
INSTALLER_ISO_ENV_VAR="MM3_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="MM3_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="MM3_CD_DEVICE"
INSTALLER_DOWNLOAD_FILES=(
  "M322DK.bin|https://archive.org/download/magnus-myggen-skumlesens-haevn/M322DK.bin"
  "M322DK.cue|https://archive.org/download/magnus-myggen-skumlesens-haevn/M322DK.cue"
)
INSTALLER_POST_ACQUIRE_HOOK="mm3_convert_bin_cue_to_iso"

INSTALLER_REQUIRED_IMAGE_PATHS=(
  "AUTORUN.INF"
  "LAUNCHER.EXE"
  "SETUP.EXE"
  "DATA1.CAB"
  "DATA1.HDR"
  "DATA2.CAB"
  "MM.ICO"
)

mm3_convert_bin_cue_to_iso() {
  local cue="$SOURCE_DIR/M322DK.cue"
  local bin="$SOURCE_DIR/M322DK.bin"
  [[ -f "$cue" ]] || iso_installer_fatal "CUE mangler: $cue"
  [[ -f "$bin" ]] || iso_installer_fatal "BIN mangler: $bin"

  if ! grep -Eq 'TRACK[[:space:]]+01[[:space:]]+MODE1/2352' "$cue"; then
    iso_installer_fatal "CUE er ikke den forventede single-track MODE1/2352 disk: $cue"
  fi

  iso_installer_log "Konverterer BIN/CUE MODE1/2352 til ISO: $ISO_PATH"
  mkdir -p "$(dirname "$ISO_PATH")"
  python3 - "$bin" "$ISO_PATH.download" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1])
dst = Path(sys.argv[2])
sector_size = 2352
payload_start = 16
payload_end = payload_start + 2048
size = src.stat().st_size
if size % sector_size:
    raise SystemExit(f'BIN size {size} is not divisible by {sector_size}')
count = 0
with src.open('rb') as f, dst.open('wb') as out:
    while True:
        sector = f.read(sector_size)
        if not sector:
            break
        if len(sector) != sector_size:
            raise SystemExit(f'partial trailing sector: {len(sector)} bytes')
        out.write(sector[payload_start:payload_end])
        count += 1
if count == 0:
    raise SystemExit('no sectors converted')
PY
  mv -f "$ISO_PATH.download" "$ISO_PATH"
}

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
