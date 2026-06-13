#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="den-lyseroede-panter-hokus-pokus-panter"
GAME_TITLE="Den Lyserøde Panter: Hokus Pokus Panter"

INSTALLER_DOWNLOAD_LABEL="archive.org reference-linket"
INSTALLER_DOWNLOAD_URL="https://archive.org/download/Panter/Panter.iso"
INSTALLER_ISO_NAME="Panter.iso"
INSTALLER_ISO_ENV_VAR="HPP_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="HPP_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="HPP_CD_DEVICE"

# Fail fast if the wrong ISO/CD was supplied. The launcher uses AUTORUN/teaser as
# fallback and prepares the actual game from INSTALL/Hpp.exe plus shared assets.
INSTALLER_REQUIRED_IMAGE_PATHS=(
  "AUTORUN.INF"
  "teaser.exe"
  "setup.exe"
  "INSTALL/Hpp.exe"
  "INSTALL/HPP.BRO"
  "INSTALL/HPP.HLP"
  "INSTALL/SONGS.SON"
  "hpp.orb"
)

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
