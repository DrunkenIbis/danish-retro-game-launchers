#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="det-magiske-jordbaer"
GAME_TITLE="Det Magiske Jordbær"

INSTALLER_DOWNLOAD_URL="https://archive.org/download/det-magiske-jordbaer/DetMagiskeJordb%C3%A6r.iso"
INSTALLER_DOWNLOAD_LABEL="archive.org reference-linket"
INSTALLER_ISO_NAME="DetMagiskeJordbaer.iso"
INSTALLER_ISO_ENV_VAR="DMJ_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="DMJ_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="DMJ_CD_DEVICE"

# Fail fast if the user downloaded/imported the wrong disc. These are the files
# the launcher depends on either directly or during local runtime preparation.
INSTALLER_REQUIRED_IMAGE_PATHS=(
  "ADVENT.EXE"
  "ADVENT.RES"
  "DOS4GW.EXE"
  "EGAVGA.BGI"
  "STRMGC.ICN"
  "STRMGC.SND"
)

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
