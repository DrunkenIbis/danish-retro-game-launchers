#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="global-operations"
GAME_TITLE="Global Operations"

GO_ZIP_NAME="Global Operations (Europe) (En,Fr,De).zip"
GO_BIN_NAME="Global Operations (Europe) (En,Fr,De).bin"
GO_CUE_NAME="Global Operations (Europe) (En,Fr,De).cue"

INSTALLER_DOWNLOAD_LABEL="archive.org reference-linket"
INSTALLER_DOWNLOAD_FILES=(
  "$GO_ZIP_NAME|https://archive.org/download/GlobalOperationsEuropeEnFrDe/Global%20Operations%20%28Europe%29%20%28En%2CFr%2CDe%29.zip"
)
INSTALLER_ISO_NAME="Global Operations (Europe) (En,Fr,De).iso"
INSTALLER_ISO_ENV_VAR="GO_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="GO_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="GO_CD_DEVICE"
INSTALLER_POST_ACQUIRE_HOOK="global_operations_prepare_iso"

INSTALLER_REQUIRED_IMAGE_PATHS=(
  "AUTORUN.INF"
  "AutoRun.exe"
  "globalops.exe"
  "secdrv.sys"
  "Setup/Setup.exe"
  "Setup/Setup.ini"
  "Setup/GAME/Engine.REZ"
  "Setup/GAME/mss32.dll"
  "Setup/GAME/Smackw32.dll"
  "Setup/GAME/goserver.exe"
  "ReadMe/readme_eng.txt"
)

global_operations_prepare_iso() {
  command -v 7z >/dev/null 2>&1 || { echo "[Global Operations] FEJL: Mangler kommando: 7z" >&2; exit 1; }
  command -v python3 >/dev/null 2>&1 || { echo "[Global Operations] FEJL: Mangler kommando: python3" >&2; exit 1; }
  mkdir -p "$SOURCE_DIR"

  local zip_path="$SOURCE_DIR/$GO_ZIP_NAME"
  local bin_path="$SOURCE_DIR/$GO_BIN_NAME"
  local cue_path="$SOURCE_DIR/$GO_CUE_NAME"

  if [[ ! -f "$bin_path" || ! -f "$cue_path" ]]; then
    [[ -f "$zip_path" ]] || { echo "[Global Operations] FEJL: Mangler ZIP: $zip_path" >&2; exit 1; }
    echo "[Global Operations] Udpakker BIN/CUE fra ZIP til ignored source-dir"
    7z x -y -o"$SOURCE_DIR" "$zip_path" "$GO_BIN_NAME" "$GO_CUE_NAME" >/dev/null
  fi

  python3 - "$bin_path" "$cue_path" "$ISO_PATH" <<'PY'
from pathlib import Path
import re, sys
bin_path = Path(sys.argv[1])
cue_path = Path(sys.argv[2])
iso_path = Path(sys.argv[3])
cue = cue_path.read_text(errors='replace').upper()
if 'TRACK 01 MODE1/2352' not in cue:
    raise SystemExit(f'Unsupported CUE layout for this recipe: {cue_path}')
sector_size = 2352
payload_start = 16
payload_size = 2048
size = bin_path.stat().st_size
if size % sector_size:
    raise SystemExit(f'BIN size is not a whole number of 2352-byte sectors: {size}')
if iso_path.exists() and iso_path.stat().st_mtime >= bin_path.stat().st_mtime:
    print(f'[Global Operations] ISO findes allerede: {iso_path}')
    raise SystemExit(0)
tmp = iso_path.with_suffix(iso_path.suffix + '.tmp')
print(f'[Global Operations] Konverterer MODE1/2352 BIN -> ISO: {iso_path}')
with bin_path.open('rb') as src, tmp.open('wb') as dst:
    while True:
        sector = src.read(sector_size)
        if not sector:
            break
        if len(sector) != sector_size:
            raise SystemExit('Short final sector')
        dst.write(sector[payload_start:payload_start + payload_size])
tmp.replace(iso_path)
PY
}

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
