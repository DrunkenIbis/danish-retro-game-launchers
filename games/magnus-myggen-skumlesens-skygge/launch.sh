#!/usr/bin/env bash
set -euo pipefail

# Magnus & Myggen: Skumlesens Hævn / Skumlesens Skygge
# Local Lutris/Wine wrapper. Extracts the ISO once, maps it as CD-ROM,
# and by default bypasses the broken old InstallShield disk-space check
# by creating a manual complete install before launching MM4.EXE.

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ISO_DEFAULT="$SELF_DIR/Magnus-Myggen-Skumlesens-Skygge.iso"
if [[ ! -e "$ISO_DEFAULT" && -e "/home/test/Hentet/Magnus-Myggen-Skumlesens-Skygge.iso" ]]; then
  ISO_DEFAULT="/home/test/Hentet/Magnus-Myggen-Skumlesens-Skygge.iso"
fi

MM2_ISO="${MM2_ISO:-$ISO_DEFAULT}"
MM2_EXTRACT_DIR="${MM2_EXTRACT_DIR:-$SELF_DIR/game-files}"
MM2_WINEPREFIX="${MM2_WINEPREFIX:-$SELF_DIR/wineprefix32}"
if command -v wine32 >/dev/null 2>&1; then
  MM2_WINE_BIN="${MM2_WINE_BIN:-wine32}"
else
  MM2_WINE_BIN="${MM2_WINE_BIN:-wine}"
fi
MM2_SEVENZ_BIN="${MM2_SEVENZ_BIN:-7z}"
MM2_LAUNCHER="${MM2_LAUNCHER:-LAUNCHER.EXE}"
MM2_CD_DRIVE="${MM2_CD_DRIVE:-d}"
MM2_CD_LABEL="${MM2_CD_LABEL:-200904171145}"
MM2_RUN_INSTALLER="${MM2_RUN_INSTALLER:-0}"
# installed = start the manually installed C:\\Program Files copy.
# cdlauncher = start D:\\LAUNCHER.EXE from the Wine CD-ROM mapping.
# cdexe = start D:\\MM4.___ directly from the Wine CD-ROM mapping.
MM2_LAUNCH_MODE="${MM2_LAUNCH_MODE:-cdexe}"
MM2_INSTALL_DIR="${MM2_INSTALL_DIR:-$MM2_WINEPREFIX/drive_c/Program Files/Skumlesens Skygge}"
MM2_INSTALLED_EXE="${MM2_INSTALLED_EXE:-$MM2_INSTALL_DIR/MM4.EXE}"
MM2_DESKTOP_NAME="${MM2_DESKTOP_NAME:-MagnusMyggen2}"
MM2_DESKTOP_SIZE="${MM2_DESKTOP_SIZE:-800x600}"
MM2_VIRTUAL_DESKTOP="${MM2_VIRTUAL_DESKTOP:-1}"
MM2_WINEDEBUG="${MM2_WINEDEBUG:--all}"
MM2_FORCE_WIN32="${MM2_FORCE_WIN32:-1}"
MM2_DRY_RUN="${MM2_DRY_RUN:-0}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Mangler kommando: $1" >&2
    exit 127
  fi
}

need_cmd "$MM2_SEVENZ_BIN"
need_cmd "$MM2_WINE_BIN"

if [[ ! -e "$MM2_ISO" ]]; then
  cat >&2 <<EOF
Kan ikke finde ISO'en:
  $MM2_ISO

Læg ISO'en i projektmappen som:
  $ISO_DEFAULT
eller sæt miljøvariablen MM2_ISO=/sti/til/fil.iso
EOF
  exit 2
fi

launcher_path="$MM2_EXTRACT_DIR/$MM2_LAUNCHER"

if [[ "$MM2_DRY_RUN" == "1" ]]; then
  echo "DRY RUN"
  echo "ISO=$MM2_ISO"
  echo "EXTRACT_DIR=$MM2_EXTRACT_DIR"
  echo "WINEPREFIX=$MM2_WINEPREFIX"
  echo "WINE_BIN=$MM2_WINE_BIN"
  echo "LAUNCHER=$launcher_path"
  echo "CD_DRIVE=${MM2_CD_DRIVE}: -> $MM2_EXTRACT_DIR"
  echo "CD_LABEL=$MM2_CD_LABEL"
  echo "RUN_INSTALLER=$MM2_RUN_INSTALLER"
  echo "LAUNCH_MODE=$MM2_LAUNCH_MODE"
  echo "INSTALL_DIR=$MM2_INSTALL_DIR"
  echo "INSTALLED_EXE=$MM2_INSTALLED_EXE"
  echo "WOULD_EXTRACT=$([[ -e "$launcher_path" ]] && echo 0 || echo 1)"
  echo "VIRTUAL_DESKTOP=$MM2_VIRTUAL_DESKTOP SIZE=$MM2_DESKTOP_SIZE"
  exit 0
fi

if [[ ! -e "$launcher_path" ]]; then
  echo "Udpakker ISO til: $MM2_EXTRACT_DIR"
  mkdir -p "$MM2_EXTRACT_DIR"
  "$MM2_SEVENZ_BIN" x -y -o"$MM2_EXTRACT_DIR" "$MM2_ISO"
fi

if [[ ! -e "$launcher_path" ]]; then
  echo "Kunne ikke finde launcher: $launcher_path" >&2
  echo "Prøv evt. MM2_LAUNCHER=SETUP.EXE eller inspicér $MM2_EXTRACT_DIR" >&2
  exit 3
fi

export WINEPREFIX="$MM2_WINEPREFIX"
export WINEDEBUG="$MM2_WINEDEBUG"
if [[ "$MM2_FORCE_WIN32" == "1" ]]; then
  export WINEARCH=win32
fi
mkdir -p "$(dirname "$MM2_WINEPREFIX")"

setup_cdrom_drive() {
  # Mange gamle InstallShield-spil tjekker specifikt efter en CD-ROM.
  # Derfor mapper vi de udpakkede ISO-filer som D: og markerer drevet som cdrom i Wine.
  local drive_lower="${MM2_CD_DRIVE,,}"
  mkdir -p "$MM2_WINEPREFIX/dosdevices"
  ln -sfn "$MM2_EXTRACT_DIR" "$MM2_WINEPREFIX/dosdevices/${drive_lower}:"
  printf '%s\n' "$MM2_CD_LABEL" > "$MM2_EXTRACT_DIR/.windows-label" 2>/dev/null || true
  "$MM2_WINE_BIN" reg add 'HKCU\Software\Wine\Drives' /v "${drive_lower}:" /d cdrom /f >/dev/null 2>&1 || true
}

manual_install_game() {
  # InstallShield på denne titel bruger en gammel diskplads-check, som kan fejle
  # på moderne store Linux-filsystemer. Spillets filer ligger allerede udpakket
  # på CD'en, så vi laver en manuel "komplet installation" i C:\Program Files.
  [[ -e "$MM2_INSTALLED_EXE" ]] && return 0
  echo "Laver manuel komplet installation til: $MM2_INSTALL_DIR"
  mkdir -p "$MM2_INSTALL_DIR"
  cp -f "$MM2_EXTRACT_DIR/MM4.___" "$MM2_INSTALLED_EXE"
  for f in CONFIG.LNG CONFMAN.EXE CPUINFO.DLL DRVMGT.DLL IVANOFF.HTM MM4SETUP.HLP MM.ICO TEST.FLC VIGTIG.TXT; do
    [[ -e "$MM2_EXTRACT_DIR/$f" ]] && cp -f "$MM2_EXTRACT_DIR/$f" "$MM2_INSTALL_DIR/"
  done
  rm -rf "$MM2_INSTALL_DIR/DAT" "$MM2_INSTALL_DIR/LEV" "$MM2_INSTALL_DIR/IMAGE"
  cp -a "$MM2_EXTRACT_DIR/DAT" "$MM2_INSTALL_DIR/DAT"
  cp -a "$MM2_EXTRACT_DIR/LEV" "$MM2_INSTALL_DIR/LEV"
  cp -a "$MM2_EXTRACT_DIR/IMAGE" "$MM2_INSTALL_DIR/IMAGE"
  if [[ -d "$MM2_EXTRACT_DIR/%SystemDrive%/Program Files/Skumlesens Skygge" ]]; then
    cp -a "$MM2_EXTRACT_DIR/%SystemDrive%/Program Files/Skumlesens Skygge/." "$MM2_INSTALL_DIR/" || true
  fi
  "$MM2_WINE_BIN" reg add 'HKLM\Software\IVANOFF Interactive\MM4' /f >/dev/null 2>&1 || true
  "$MM2_WINE_BIN" reg add 'HKLM\Software\IVANOFF Interactive\Magnus & Myggen, Skumlesens Skygge\1.00.000' /f >/dev/null 2>&1 || true
  "$MM2_WINE_BIN" reg add 'HKLM\Software\Microsoft\Windows\CurrentVersion\App Paths\mm4.exe' /ve /d 'C:\Program Files\Skumlesens Skygge\MM4.EXE' /f >/dev/null 2>&1 || true
  "$MM2_WINE_BIN" reg add 'HKLM\Software\Microsoft\Windows\CurrentVersion\App Paths\mm4.exe' /v Path /d 'C:\Program Files\Skumlesens Skygge' /f >/dev/null 2>&1 || true
}

setup_cdrom_drive
if [[ "$MM2_RUN_INSTALLER" != "1" ]]; then
  manual_install_game
fi

if [[ "$MM2_RUN_INSTALLER" == "1" ]]; then
  # Bagudkompatibel override fra tidligere debugging: kør autorun-launcheren fra CD-drevet.
  MM2_LAUNCH_MODE="cdlauncher"
fi

case "$MM2_LAUNCH_MODE" in
  installed)
    cd "$MM2_INSTALL_DIR"
    wine_launcher='C:\Program Files\Skumlesens Skygge\MM4.EXE'
    ;;
  cdlauncher)
    cd "$MM2_EXTRACT_DIR"
    wine_launcher="${MM2_CD_DRIVE^^}:\\$MM2_LAUNCHER"
    ;;
  cdexe)
    cd "$MM2_EXTRACT_DIR"
    wine_launcher="${MM2_CD_DRIVE^^}:\\MM4.___"
    ;;
  *)
    echo "Ukendt MM2_LAUNCH_MODE=$MM2_LAUNCH_MODE (brug: installed, cdlauncher, cdexe)" >&2
    exit 4
    ;;
esac

if [[ "$MM2_VIRTUAL_DESKTOP" == "1" ]]; then
  "$MM2_WINE_BIN" explorer "/desktop=$MM2_DESKTOP_NAME,$MM2_DESKTOP_SIZE" "$wine_launcher"
else
  "$MM2_WINE_BIN" "$wine_launcher"
fi
# Wine kan returnere fra start.exe/explorer før selve spilprocessen lukker.
# Vent her, så Lutris ikke tror spillet crasher og dræber child-processerne.
"$MM2_WINE_BIN" wineserver -w 2>/dev/null || wineserver -w 2>/dev/null || true
