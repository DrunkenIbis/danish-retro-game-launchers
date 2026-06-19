#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="overboard"
GAME_TITLE="Overboard! / Shipwreckers!"

INSTALLER_DOWNLOAD_LABEL="archive.org ZIP med BIN/CUE reference-linket"
INSTALLER_ISO_NAME="OVERBOARD.iso"
INSTALLER_ISO_ENV_VAR="OVERBOARD_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="OVERBOARD_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="OVERBOARD_CD_DEVICE"
INSTALLER_DOWNLOAD_FILES=(
  "OVERBOARD.zip|https://archive.org/download/overboard_202506/OVERBOARD.zip"
)
INSTALLER_POST_ACQUIRE_HOOK="overboard_convert_zip_bin_cue_to_iso"

# The archive.org file is a ZIP containing a mixed-mode BIN/CUE. Keep canonical
# OVERBOARD.bin/OVERBOARD.cue copies alongside the derived ISO so the launcher
# can try original-media-backed CD-ROM semantics, not only the converted data track.
# Validate the files the launcher needs from the converted data-track ISO.
INSTALLER_REQUIRED_IMAGE_PATHS=(
  "AUTORUN.INF"
  "AUTORUN.EXE"
  "OB.EXE"
  "RES.RDA"
  "RES.RDR"
  "RES.RDT"
  "LANG.DAT"
  "OS.DAT"
  "COMPLETE.MPX"
  "INTRO.MPX"
)

overboard_convert_zip_bin_cue_to_iso() {
  local zip="$SOURCE_DIR/OVERBOARD.zip"
  local work="$SOURCE_DIR/.overboard-extract"
  local cue="$work/OVERBOARD.cue"
  local bin="$work/OVERBOARD.bin"
  local canonical_cue="$SOURCE_DIR/OVERBOARD.cue"
  local canonical_bin="$SOURCE_DIR/OVERBOARD.bin"
  [[ -f "$zip" ]] || iso_installer_fatal "ZIP mangler: $zip"
  iso_installer_need_cmd unzip
  iso_installer_need_cmd python3

  rm -rf "$work"
  mkdir -p "$work"
  iso_installer_log "Udpakker BIN/CUE fra ZIP: $zip"
  unzip -q -o "$zip" OVERBOARD.bin OVERBOARD.cue -d "$work"
  [[ -f "$cue" ]] || iso_installer_fatal "CUE mangler efter unzip: $cue"
  [[ -f "$bin" ]] || iso_installer_fatal "BIN mangler efter unzip: $bin"
  cp -f "$cue" "$canonical_cue"
  cp -f "$bin" "$canonical_bin"
  iso_installer_log "Gemmer originale BIN/CUE til launcher-tests: $canonical_bin / $canonical_cue"

  iso_installer_log "Konverterer første MODE2/2352 data-track til ISO: $ISO_PATH"
  mkdir -p "$(dirname "$ISO_PATH")"
  python3 - "$cue" "$bin" "$ISO_PATH.download" <<'PY'
from pathlib import Path
import re
import sys

cue = Path(sys.argv[1])
bin_path = Path(sys.argv[2])
out_path = Path(sys.argv[3])
text = cue.read_text(errors='replace')
if not re.search(r'TRACK\s+01\s+MODE2/2352', text, re.IGNORECASE):
    raise SystemExit(f'{cue} is not the expected TRACK 01 MODE2/2352 disc')
# Mixed-mode CD: only track 1 is the data ISO. Stop at TRACK 02 INDEX 00
# (pregap), otherwise the converted ISO contains audio sectors and tools report
# misleading archive/volume-size errors.
match = re.search(r'TRACK\s+02\s+AUDIO\s+INDEX\s+00\s+(\d+):(\d+):(\d+)', text, re.IGNORECASE | re.DOTALL)
if not match:
    match = re.search(r'TRACK\s+02\s+AUDIO\s+INDEX\s+01\s+(\d+):(\d+):(\d+)', text, re.IGNORECASE | re.DOTALL)
if not match:
    raise SystemExit('could not find TRACK 02 start in CUE')
minutes, seconds, frames = map(int, match.groups())
data_sectors = ((minutes * 60) + seconds) * 75 + frames
sector_size = 2352
payload_start = 24
payload_end = payload_start + 2048
with bin_path.open('rb') as src, out_path.open('wb') as dst:
    for sector_no in range(data_sectors):
        sector = src.read(sector_size)
        if len(sector) != sector_size:
            raise SystemExit(f'partial sector {sector_no}: {len(sector)} bytes')
        dst.write(sector[payload_start:payload_end])
if out_path.stat().st_size != data_sectors * 2048:
    raise SystemExit('converted ISO size mismatch')
# Some Aaru mixed-mode dumps preserve the full-disc sector count in the ISO9660
# primary descriptor. Patch it to the actual converted data-track length so 7z
# and the shared validator do not report "Unexpected end of archive".
with out_path.open('r+b') as iso:
    for descriptor_sector in range(16, 32):
        iso.seek(descriptor_sector * 2048)
        header = iso.read(8)
        if len(header) < 8 or header[1:6] != b'CD001':
            continue
        dtype = header[0]
        if dtype in (1, 2):
            iso.seek(descriptor_sector * 2048 + 80)
            iso.write(data_sectors.to_bytes(4, 'little'))
            iso.write(data_sectors.to_bytes(4, 'big'))
        if dtype == 255:
            break
PY
  mv -f "$ISO_PATH.download" "$ISO_PATH"
  rm -rf "$work"
}

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
