#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="magnus-myggen-leg-og-laer"
GAME_TITLE="Magnus & Myggen: Leg og Lær"

INSTALLER_DOWNLOAD_LABEL="reference-linket"
INSTALLER_ISO_NAME="Magnus-Myggen-Leg-og-Laer.iso"
INSTALLER_ISO_ENV_VAR="MM1_ISO_PATH"
INSTALLER_SOURCE_DIR_ENV_VAR="MM1_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="MM1_CD_DEVICE"

# This recipe intentionally does not auto-download copyrighted game media.
# Use --existing with an ISO in local/sources/magnus-myggen-leg-og-laer/ or
# --cd /dev/sr0 to import your own original disc.
INSTALLER_REQUIRED_IMAGE_PATHS=(
  "MAGNUS.EXE"
  "MMSYS.DLL"
  "MAGNUS0.DXR"
  "MAGNUS1.DXR"
  "MMB01.DXR"
  "VFW/SETUP.EXE"
)

source "$REPO_ROOT/scripts/iso-installer.sh"

# This WinISO-created disc can make 7z exit nonzero with an "Incorrect
# big-endian headers" warning after it has listed/extracted the files correctly.
# Validate by checking the emitted path list instead of treating 7z's exit code
# alone as fatal.
iso_installer_validate_image() {
  local image="$1"
  [[ -f "$image" ]] || iso_installer_fatal "ISO blev ikke fundet: $image"
  iso_installer_need_cmd 7z
  iso_installer_log "Validerer ISO-indhold tidligt..."

  local list_file required missing=0 list_dir
  list_dir="$(dirname "$image")"
  if [[ ! -d "$list_dir" || ! -w "$list_dir" ]]; then
    list_dir="/var/tmp"
  fi
  list_file="$(mktemp -p "$list_dir" .iso-installer-paths.XXXXXX)"
  7z l -slt "$image" | awk -F' = ' '$1 == "Path" && $2 != "" {print $2}' > "$list_file" || true
  for required in "${INSTALLER_REQUIRED_IMAGE_PATHS[@]}"; do
    if ! grep -Fxqi -- "$required" "$list_file"; then
      printf '[%s] Mangler i ISO: %s\n' "${GAME_TITLE}" "$required" >&2
      missing=1
    fi
  done
  rm -f "$list_file"
  [[ "$missing" == 0 ]] || iso_installer_fatal "ISO'en matcher ikke opskriften. Forkert fil, dårlig download eller dårlig CD-import."
}

iso_installer_main "$@"
