#!/usr/bin/env bash
set -euo pipefail

# Den Lyserøde Panter: På hemmelig mission i udlandet
# Lokal Lutris/Wine-wrapper til ISO'en i samme mappe.
# Den udpakker ISO'en første gang, mapper den som CD-ROM i et win32 Wine-prefix,
# og starter som standard fra en manuel clean install-kopi uden gamle system-DLL'er.

SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

PP_ISO_DEFAULT="$SELF_DIR/Den Lyserøde Panter på hemmelig mission i udlandet.iso"
PP_ISO="${PP_ISO:-$PP_ISO_DEFAULT}"
PP_EXTRACT_DIR="${PP_EXTRACT_DIR:-$SELF_DIR/game-files}"
PP_WINEPREFIX="${PP_WINEPREFIX:-$SELF_DIR/wineprefix32}"
if command -v wine32 >/dev/null 2>&1; then
  PP_WINE_BIN="${PP_WINE_BIN:-wine32}"
else
  PP_WINE_BIN="${PP_WINE_BIN:-wine}"
fi
PP_SEVENZ_BIN="${PP_SEVENZ_BIN:-7z}"
PP_CD_DRIVE="${PP_CD_DRIVE:-d}"
PP_CD_LABEL="${PP_CD_LABEL:-PANTER}"
PP_DESKTOP_NAME="${PP_DESKTOP_NAME:-PinkPanther}"
PP_DESKTOP_SIZE="${PP_DESKTOP_SIZE:-640x480}"
PP_VIRTUAL_DESKTOP="${PP_VIRTUAL_DESKTOP:-1}"
PP_WINEDEBUG="${PP_WINEDEBUG:--all}"
PP_FORCE_WIN32="${PP_FORCE_WIN32:-1}"
PP_DRY_RUN="${PP_DRY_RUN:-0}"
PP_PREPARE_ONLY="${PP_PREPARE_ONLY:-0}"
PP_INSTALL_ONLY="${PP_INSTALL_ONLY:-0}"
PP_WINEBOOT_TIMEOUT="${PP_WINEBOOT_TIMEOUT:-45}"

# launch_mode:
#   cdexe     = start D:\INSTALL\PPTP.EXE direkte (kan fejle pga. gamle system-DLL'er)
#   teaser    = start D:\TEASER.EXE fra autorun
#   setup     = kør D:\SETUP.EXE (16-bit Windows 3.x installer; kræver wine32/win32-prefix)
#   installed = start C:\Program Files\Pink Panther\PPTP.EXE efter manuel clean install
PP_LAUNCH_MODE="${PP_LAUNCH_MODE:-installed}"
PP_INSTALL_DIR="${PP_INSTALL_DIR:-$PP_WINEPREFIX/drive_c/Program Files/Pink Panther}"
PP_INSTALLED_EXE="${PP_INSTALLED_EXE:-$PP_INSTALL_DIR/PPTP.EXE}"

need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Mangler kommando: $1" >&2
    exit 127
  fi
}

need_cmd "$PP_SEVENZ_BIN"
need_cmd "$PP_WINE_BIN"

if [[ ! -e "$PP_ISO" ]]; then
  cat >&2 <<EOF
Kan ikke finde ISO'en:
  $PP_ISO

Læg ISO'en i projektmappen som:
  $PP_ISO_DEFAULT
eller sæt miljøvariablen PP_ISO=/sti/til/fil.iso
EOF
  exit 2
fi

main_exe="$PP_EXTRACT_DIR/INSTALL/PPTP.EXE"

if [[ "$PP_DRY_RUN" == "1" ]]; then
  echo "DRY RUN"
  echo "ISO=$PP_ISO"
  echo "EXTRACT_DIR=$PP_EXTRACT_DIR"
  echo "WINEPREFIX=$PP_WINEPREFIX"
  echo "WINE_BIN=$PP_WINE_BIN"
  echo "CD_DRIVE=${PP_CD_DRIVE}: -> $PP_EXTRACT_DIR"
  echo "CD_LABEL=$PP_CD_LABEL"
  echo "LAUNCH_MODE=$PP_LAUNCH_MODE"
  echo "MAIN_EXE=$main_exe"
  echo "INSTALL_DIR=$PP_INSTALL_DIR"
  echo "INSTALLED_EXE=$PP_INSTALLED_EXE"
  echo "WOULD_EXTRACT=$([[ -e "$main_exe" ]] && echo 0 || echo 1)"
  echo "VIRTUAL_DESKTOP=$PP_VIRTUAL_DESKTOP SIZE=$PP_DESKTOP_SIZE"
  exit 0
fi

if [[ ! -e "$main_exe" ]]; then
  echo "Udpakker ISO til: $PP_EXTRACT_DIR"
  mkdir -p "$PP_EXTRACT_DIR"
  "$PP_SEVENZ_BIN" x -y -o"$PP_EXTRACT_DIR" "$PP_ISO"
fi

if [[ ! -e "$main_exe" ]]; then
  echo "Kunne ikke finde spillets executable: $main_exe" >&2
  echo "Inspicér evt. $PP_EXTRACT_DIR eller prøv PP_LAUNCH_MODE=setup" >&2
  exit 3
fi

export WINEPREFIX="$PP_WINEPREFIX"
export WINEDEBUG="$PP_WINEDEBUG"
if [[ "$PP_FORCE_WIN32" == "1" ]]; then
  export WINEARCH=win32
fi
mkdir -p "$(dirname "$PP_WINEPREFIX")"

setup_cdrom_drive() {
  local drive_lower="${PP_CD_DRIVE,,}"
  mkdir -p "$PP_WINEPREFIX/dosdevices"
  ln -sfn "$PP_EXTRACT_DIR" "$PP_WINEPREFIX/dosdevices/${drive_lower}:"
  printf '%s\n' "$PP_CD_LABEL" > "$PP_EXTRACT_DIR/.windows-label" 2>/dev/null || true

  # Vigtigt: Kør IKKE `wine reg add` her.
  # På en helt ny prefix tvinger det Wine til at bygge hele prefixet midt i
  # Lutris' installer-fase, hvor den kan stå længe på "Wine configuration is
  # being updated". Symlinket + .windows-label er nok til dette spil.
}

repair_broken_prefix_if_needed() {
  # Den forrige version kunne efterlade en halv-oprettet prefix:
  # system.reg/user.reg fandtes, men drive_c/windows manglede. Så starter Wine
  # med gentagne "could not open working directory C:\\windows\\system32".
  if [[ -d "$PP_WINEPREFIX" && ! -d "$PP_WINEPREFIX/drive_c/windows" ]]; then
    local backup="${PP_WINEPREFIX}.broken.$(date +%Y%m%d-%H%M%S)"
    echo "Finder halvfærdig Wine-prefix uden drive_c/windows." >&2
    echo "Flytter den til: $backup" >&2
    mv "$PP_WINEPREFIX" "$backup"
  fi
}

initialize_wine_prefix() {
  # Lad Wine bygge C:-drevet FØR vi selv opretter dosdevices/d:.
  # Hvis vi opretter wineprefix32/dosdevices først, tror Wine at prefixen findes,
  # men den mangler C:\windows\system32 og går i loop.
  if [[ ! -d "$PP_WINEPREFIX/drive_c/windows/system32" ]]; then
    echo "Initialiserer Wine-prefix: $PP_WINEPREFIX"
    local boot_status=0
    if command -v timeout >/dev/null 2>&1; then
      timeout "${PP_WINEBOOT_TIMEOUT}s" "$PP_WINE_BIN" wineboot -u || boot_status=$?
    else
      "$PP_WINE_BIN" wineboot -u || boot_status=$?
    fi
    if [[ "$boot_status" != "0" && -d "$PP_WINEPREFIX/drive_c/windows/system32" ]]; then
      echo "wineboot returnerede $boot_status, men prefixens C:-drev findes; fortsætter."
      "$PP_WINE_BIN" wineserver -k >/dev/null 2>&1 || true
    elif [[ "$boot_status" != "0" ]]; then
      echo "wineboot fejlede med status $boot_status før prefixen var klar." >&2
      exit "$boot_status"
    fi
  fi
  if [[ ! -d "$PP_WINEPREFIX/drive_c/windows/system32" ]]; then
    echo "Wine-prefix blev ikke initialiseret korrekt: $PP_WINEPREFIX" >&2
    exit 5
  fi
}

manual_install_game() {
  local marker="$PP_INSTALL_DIR/.pink-panther-clean-install-v2"
  if [[ -e "$PP_INSTALLED_EXE" && -e "$marker" ]]; then
    return 0
  fi

  echo "Laver manuel clean install til: $PP_INSTALL_DIR"
  mkdir -p "$PP_INSTALL_DIR"

  # Kopiér spilfilerne én for én, men udelad gamle Windows/Win32s systemfiler.
  # Hvis de ligger ved siden af PPTP.EXE, shadow'er de Wine's egne DLL'er og giver
  # c000007b / "Importing dlls ... failed".
  while IFS= read -r -d '' src; do
    local name
    name="$(basename "$src")"
    case "${name^^}" in
      VERSION.DLL|COMDLG32.DLL|WINSPOOL.DRV|SHELL32.DLL|COMCTL32.DLL|LZ32.DLL|NETAPI32.DLL|RICHED32.DLL|WINMM.DLL|WINMM16.DLL|OLECLI.DLL|OLECLI32.DLL|OLESVR32.DLL|W32S.386|W32SCOMB.DLL|W32SKRNL.DLL|W32SYS.DLL|WIN32S.EXE|WIN32S16.DLL|WING.DLL|WING32.DLL|WINGDE.DLL|WINGDIB.DRV|WINHLP32.EXE)
        echo "Udelader gammel systemfil: $name"
        ;;
      *)
        cp -a "$src" "$PP_INSTALL_DIR/"
        ;;
    esac
  done < <(find "$PP_EXTRACT_DIR/INSTALL" -mindepth 1 -maxdepth 1 -print0)

  # Nogle versioner leder efter disse datafiler i CD-roden.
  for f in ALLSONGS.PTP PPTP.ORB LICENSE.TXT README.WRI; do
    [[ -e "$PP_EXTRACT_DIR/$f" ]] && cp -f "$PP_EXTRACT_DIR/$f" "$PP_INSTALL_DIR/"
  done

  touch "$marker"
}

repair_broken_prefix_if_needed
initialize_wine_prefix
setup_cdrom_drive

if [[ "$PP_PREPARE_ONLY" == "1" ]]; then
  echo "PREPARE ONLY OK"
  echo "ISO udpakket: $PP_EXTRACT_DIR"
  echo "CD-ROM mapping: ${PP_CD_DRIVE}: -> $PP_EXTRACT_DIR"
  echo "Launch target: $main_exe"
  exit 0
fi

if [[ "$PP_INSTALL_ONLY" == "1" ]]; then
  manual_install_game
  echo "INSTALL ONLY OK"
  echo "Installeret exe: $PP_INSTALLED_EXE"
  exit 0
fi

case "$PP_LAUNCH_MODE" in
  cdexe)
    cd "$PP_EXTRACT_DIR/INSTALL"
    wine_launcher="$main_exe"
    ;;
  teaser)
    cd "$PP_EXTRACT_DIR"
    wine_launcher="$PP_EXTRACT_DIR/TEASER.EXE"
    ;;
  setup)
    cd "$PP_EXTRACT_DIR"
    wine_launcher="$PP_EXTRACT_DIR/SETUP.EXE"
    ;;
  installed)
    manual_install_game
    cd "$PP_INSTALL_DIR"
    wine_launcher='C:\Program Files\Pink Panther\PPTP.EXE'
    ;;
  *)
    echo "Ukendt PP_LAUNCH_MODE=$PP_LAUNCH_MODE (brug: cdexe, teaser, setup, installed)" >&2
    exit 4
    ;;
esac

if [[ "$PP_VIRTUAL_DESKTOP" == "1" ]]; then
  "$PP_WINE_BIN" explorer "/desktop=$PP_DESKTOP_NAME,$PP_DESKTOP_SIZE" "$wine_launcher"
else
  "$PP_WINE_BIN" "$wine_launcher"
fi
# Vent så Lutris ikke tror, at spillet er færdigt for tidligt.
"$PP_WINE_BIN" wineserver -w 2>/dev/null || wineserver -w 2>/dev/null || true
