#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="atomic-bomberman-1997"
GAME_TITLE="Atomic Bomberman"

INSTALLER_DOWNLOAD_LABEL="archive.org reference-linket"
INSTALLER_DOWNLOAD_URL="https://archive.org/download/atomic-bomberman_202504/Atomic%20Bomberman.ISO"
INSTALLER_ISO_NAME="Atomic Bomberman.ISO"
INSTALLER_ISO_ENV_VAR="AB_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="AB_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="AB_CD_DEVICE"

INSTALLER_REQUIRED_IMAGE_PATHS=(
  "AUTORUN.INF"
  "AUTORUN.EXE"
  "BM95.EXE"
  "CFG.INI"
  "DATA/ANI/MASTER.ALI"
  "DATA/RES/TITLE.PCX"
  "DATA/RES/SOUNDLST.RES"
  "DATA/SCHEMES/BASIC.SCH"
)

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"