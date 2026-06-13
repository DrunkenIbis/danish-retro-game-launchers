#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="pink-panther-passport-to-peril"
GAME_TITLE="Den Lyserøde Panter på hemmelig mission i udlandet / Pink Panther: Passport to Peril (DK)"

INSTALLER_DOWNLOAD_LABEL="archive.org reference-linket"
INSTALLER_DOWNLOAD_URL="https://archive.org/download/DenLyserodePanterpahemmeligmissioniudlandet/PANTER.iso"
INSTALLER_ISO_NAME="PANTER.iso"
INSTALLER_ISO_ENV_VAR="PP_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="PP_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="PP_CD_DEVICE"

# Valider de filer launcheren reelt bruger, før Wine overhovedet startes.
# AUTORUN peger på teaser.exe, men den stabile game path er en clean install fra
# INSTALL/PPTP.EXE plus de store resource-filer i CD-roden.
INSTALLER_REQUIRED_IMAGE_PATHS=(
  "AUTORUN.INF"
  "TEASER.EXE"
  "SETUP.EXE"
  "INSTALL/PPTP.EXE"
  "INSTALL/PPTP.BRO"
  "INSTALL/PPTP.HLP"
  "INSTALL/ALLSONGS.PTP"
  "ALLSONGS.PTP"
  "PPTP.ORB"
)

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
