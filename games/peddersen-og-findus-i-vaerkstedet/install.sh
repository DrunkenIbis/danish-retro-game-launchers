#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="peddersen-og-findus-i-vaerkstedet"
GAME_TITLE="Peddersen og Findus i værkstedet"

INSTALLER_DOWNLOAD_LABEL="archive.org reference-linket"
INSTALLER_DOWNLOAD_URL="https://archive.org/download/peddersen-og-findus-i-vaerkstedet_202201/Peddersen%20og%20Findus%20i%20v%C3%A6rkstedet.iso"
INSTALLER_ISO_NAME="Peddersen-og-Findus-i-vaerkstedet.iso"
INSTALLER_ISO_ENV_VAR="FINDUS1_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="FINDUS1_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="FINDUS1_CD_DEVICE"

# Valider de filer launcheren reelt bruger, før Wine overhovedet startes.
# AUTORUN.INF peger på autorun/Autorun.exe, men selve spillet kræver en
# installeret Gammafon/Director runtime-state. launch.sh laver derfor en manuel
# runtime-install fra DATA/ + Media/ og skriver den registry-nøgle som spillet
# bruger til at afgøre om Findus1 er installeret.
INSTALLER_REQUIRED_IMAGE_PATHS=(
  "autorun.inf"
  "autorun/Autorun.exe"
  "autorun/autorun.ini"
  "Installér Findus1.exe"
  "DATA/Findus1.exe"
  "DATA/Findus1.ini"
  "DATA/Indstillinger.exe"
  "DATA/Xtras/DirectOS.x32"
  "DATA/Xtras/DirectSound.x32"
  "Media/start.dxr"
  "Media/gammafon.dxr"
  "Media/garden.dxr"
  "Media/Cast/shared.cxt"
)

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
