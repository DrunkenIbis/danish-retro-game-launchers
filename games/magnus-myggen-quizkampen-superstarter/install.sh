#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="magnus-myggen-quizkampen-superstarter"
GAME_TITLE="Magnus & Myggen: Quizkampen Superstarter"

INSTALLER_DOWNLOAD_URL="https://archive.org/download/magnus-myggen-quizkampen-superstarter-version/Quizkampen%20Superstarter%20Version.iso"
INSTALLER_DOWNLOAD_LABEL="archive.org reference-linket"
INSTALLER_ISO_NAME="Quizkampen Superstarter Version.iso"
INSTALLER_ISO_ENV_VAR="MMQ_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="MMQ_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="MMQ_CD_DEVICE"

# Fail fast if the user downloaded/imported the wrong disc. The launcher uses
# the CD root for LAUNCHER.EXE/SETUP.EXE fallback modes and manually extracts the
# Director runtime/game files from DATA1.CAB.
INSTALLER_REQUIRED_IMAGE_PATHS=(
  "AUTORUN.INF"
  "LAUNCHER.EXE"
  "SETUP.EXE"
  "DATA1.CAB"
  "DATA1.HDR"
  "DATA2.CAB"
  "MM.ICO"
)

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
