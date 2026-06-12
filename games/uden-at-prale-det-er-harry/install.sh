#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="uden-at-prale-det-er-harry"
GAME_TITLE="Uden at prale, det er Harry"

INSTALLER_DOWNLOAD_LABEL="archive.org reference-linket"
INSTALLER_ISO_NAME="uden-at-prale-det-er-harry.iso"
INSTALLER_ISO_ENV_VAR="HARRY_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="HARRY_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="HARRY_CD_DEVICE"
INSTALLER_DOWNLOAD_FILES=(
  "uden-at-prale-det-er-harry.bin|https://archive.org/download/uden-at-prale-det-er-harry-titoonic-5707844000016/uden-at-prale-det-er-harry.bin"
  "uden-at-prale-det-er-harry.cue|https://archive.org/download/uden-at-prale-det-er-harry-titoonic-5707844000016/uden-at-prale-det-er-harry.cue"
)
INSTALLER_POST_ACQUIRE_HOOK="harry_convert_bin_cue_to_iso"

# Fail fast if the wrong BIN/CUE or CD was supplied. The launcher needs the CD
# menu/setup files, and setup needs the split setup-*.bin payload files.
INSTALLER_REQUIRED_IMAGE_PATHS=(
  "autorun.inf"
  "CDmenu.exe"
  "CDmenu.ini"
  "harry.ico"
  "setup.exe"
  "setup-1.bin"
  "setup-27.bin"
)

harry_convert_bin_cue_to_iso() {
  local cue="$SOURCE_DIR/uden-at-prale-det-er-harry.cue"
  local bin="$SOURCE_DIR/uden-at-prale-det-er-harry.bin"
  [[ -f "$cue" ]] || iso_installer_fatal "CUE mangler: $cue"
  [[ -f "$bin" ]] || iso_installer_fatal "BIN mangler: $bin"

  if ! grep -Eq 'TRACK[[:space:]]+01[[:space:]]+MODE2/2352' "$cue"; then
    iso_installer_fatal "CUE er ikke den forventede single-track MODE2/2352 disk: $cue"
  fi

  iso_installer_log "Konverterer BIN/CUE MODE2/2352 til ISO: $ISO_PATH"
  mkdir -p "$(dirname "$ISO_PATH")"
  python3 - "$bin" "$ISO_PATH.download" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1])
dst = Path(sys.argv[2])
sector_size = 2352
payload_start = 24
payload_end = 2072
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
