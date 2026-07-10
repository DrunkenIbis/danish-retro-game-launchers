#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="gold-and-glory-the-road-to-el-dorado"
GAME_TITLE="Gold and Glory: The Road to El Dorado"

INSTALLER_DOWNLOAD_LABEL="archive.org reference-linket"
INSTALLER_DOWNLOAD_URL="https://archive.org/download/edc2000/ED_CD.iso"
INSTALLER_ISO_NAME="ED_CD.iso"
INSTALLER_ISO_ENV_VAR="GGED_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="GGED_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="GGED_CD_DEVICE"

INSTALLER_REQUIRED_IMAGE_PATHS=(
  "autorun.inf"
  "setup.exe"
  "Setup2.exe"
  "engine/eldorado.ini"
  "engine/linc/engine.exe"
  "engine/linc/binkw32.dll"
  "engine/linc/gfxlib.dll"
  "engine/linc/readme.txt"
  "g/music.clu"
  "g/samples.clu"
  "g/speech.clu"
  "gmovies/intro.bik"
  "movies/m01final.bik"
)

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
