#!/usr/bin/env bash
set -Eeuo pipefail

# Den Lyserøde Panter på hemmelig mission i udlandet
# Pink Panther: Passport to Peril (dansk CD, volume label PANTER)
#
# VIGTIGE KOMPATIBILITETSVALG (holdes her, så Lutris/AppImage kun kalder wrapperen):
# 1) Recipe-only stier: ISO'en læses fra local/sources/<game-id>/PANTER.iso
#    eller PP_ISO, mens udpakning, Wine-prefix og clean install skrives til
#    local/runtime/<game-id> eller PP_RUNTIME_DIR. Ingen private spilfiler hører
#    hjemme i Git-repoet.
# 2) Win32/Wine32-prefix: SETUP.EXE er en gammel Win16/NE Windows 3.1-installer,
#    mens det egentlige spil INSTALL/PPTP.EXE er PE32. Et win32-prefix via wine32
#    er den mest stabile vej for denne Win95/Win98-era titel.
# 3) Manuel clean install: INSTALL/ indeholder gamle Windows/Win32s system-DLL'er
#    (VERSION.DLL, COMDLG32.DLL, SHELL32.DLL, WINSPOOL.DRV, WinG/Win32s m.fl.).
#    Hvis de køres ved siden af PPTP.EXE, shadow'er de Wine's egne DLL'er og gav
#    c000007b/import-loader fejl i den oprindelige fejlsøgning. Launcheren kopierer
#    derfor kun spil/datafiler til C:\Program Files\Pink Panther og udelader de
#    gamle systemfiler.
# 4) CD-ROM mapping: Den udpakkede ISO mappes som D: med label PANTER, så spillets
#    ressourceopslag fortsat ser den originale CD-kontekst.
# 5) Win98 + Wine virtual desktop: Windows-version sættes til win98 og spillet
#    startes som standard i en 640x480 Wine desktop. Det matcher tidsperioden og
#    undgår at gamle 2D/DirectDraw-vinduer forsvinder under moderne window managers.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_NAME="pink-panther-passport-to-peril"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${PP_SOURCE_DIR:-$SOURCE_BASE/$PROJECT_NAME}"
RUNTIME_DIR="${PP_RUNTIME_DIR:-$RUNTIME_BASE/$PROJECT_NAME}"
ISO_PATH="${PP_ISO:-$SOURCE_DIR/PANTER.iso}"
CDROM_DIR="${PP_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
WINEPREFIX_DIR="${PP_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}"
INSTALL_DIR="${PP_INSTALL_DIR:-$WINEPREFIX_DIR/drive_c/Program Files/Pink Panther}"

SEVENZ_BIN="${PP_SEVENZ_BIN:-7z}"
if command -v wine32 >/dev/null 2>&1; then
  WINE_BIN="${PP_WINE_BIN:-wine32}"
else
  WINE_BIN="${PP_WINE_BIN:-wine}"
fi
WINEBOOT_TIMEOUT="${PP_WINEBOOT_TIMEOUT:-90}"
WINEDEBUG_VALUE="${PP_WINEDEBUG:--all}"
MODE="${PP_MODE:-${PP_LAUNCH_MODE:-game}}"
CD_DRIVE="${PP_CD_DRIVE:-d}"
CD_LABEL="${PP_CD_LABEL:-PANTER}"
DESKTOP_NAME="${PP_DESKTOP_NAME:-PinkPanther}"
DESKTOP_SIZE="${PP_DESKTOP_SIZE:-640x480}"
VIRTUAL_DESKTOP="${PP_VIRTUAL_DESKTOP:-1}"
FORCE_WIN32="${PP_FORCE_WIN32:-1}"
DRY_RUN="${PP_DRY_RUN:-0}"

log() { printf '[Pink Panther Passport] %s\n' "$*"; }
fatal() { printf '[Pink Panther Passport] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

usage() {
  cat <<EOF
Brug: ./launch.sh

Miljøvariabler:
  PP_MODE=game|prepare|cdgame|teaser|setup|kill  (default: game)
  PP_ISO=/sti/til/PANTER.iso
  PP_SOURCE_DIR=/mappe/med/PANTER.iso
  PP_RUNTIME_DIR=/runtime/mappe
  PP_WINEPREFIX=/runtime/wineprefix32
  PP_WINE_BIN=wine32|wine
  PP_VIRTUAL_DESKTOP=0|1
  PP_DESKTOP_SIZE=640x480
  PP_DRY_RUN=1

Private standardstier:
  ISO:     $ISO_PATH
  Runtime: $RUNTIME_DIR
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) fatal "Ukendt argument: $1 (brug PP_MODE=... for launch-mode)" ;;
esac

MAIN_EXE="$CDROM_DIR/INSTALL/PPTP.EXE"
INSTALLED_EXE="$INSTALL_DIR/PPTP.EXE"

if [[ "$DRY_RUN" == "1" ]]; then
  cat <<EOF
DRY RUN
PROJECT_NAME=$PROJECT_NAME
ISO_PATH=$ISO_PATH
CDROM_DIR=$CDROM_DIR
RUNTIME_DIR=$RUNTIME_DIR
WINEPREFIX=$WINEPREFIX_DIR
WINE_BIN=$WINE_BIN
WINEARCH=$([[ "$FORCE_WIN32" == "1" ]] && echo win32 || echo '<unset>')
CD_DRIVE=${CD_DRIVE}: -> $CDROM_DIR
CD_LABEL=$CD_LABEL
MODE=$MODE
MAIN_EXE=$MAIN_EXE
INSTALLED_EXE=$INSTALLED_EXE
VIRTUAL_DESKTOP=$VIRTUAL_DESKTOP
DESKTOP_SIZE=$DESKTOP_SIZE
WOULD_EXTRACT=$([[ -f "$MAIN_EXE" ]] && echo 0 || echo 1)
EOF
  exit 0
fi

need_cmd "$SEVENZ_BIN"
need_cmd "$WINE_BIN"

if [[ "$MODE" == "kill" ]]; then
  export WINEPREFIX="$WINEPREFIX_DIR"
  if command -v wineserver >/dev/null 2>&1; then
    wineserver -k >/dev/null 2>&1 || true
  else
    "$WINE_BIN" wineserver -k >/dev/null 2>&1 || true
  fi
  log "Wine-prefix stoppet: $WINEPREFIX_DIR"
  exit 0
fi

extract_cdrom() {
  if [[ -f "$MAIN_EXE" && -f "$CDROM_DIR/AUTORUN.INF" && -f "$CDROM_DIR/PPTP.ORB" ]]; then
    return 0
  fi
  [[ -f "$ISO_PATH" ]] || fatal "Kan ikke finde ISO: $ISO_PATH. Kør ./install.sh --download --no-launch eller sæt PP_ISO."
  log "Udpakker ISO til: $CDROM_DIR"
  rm -rf "$CDROM_DIR.tmp"
  mkdir -p "$CDROM_DIR.tmp"
  "$SEVENZ_BIN" x -y -o"$CDROM_DIR.tmp" "$ISO_PATH"
  [[ -f "$CDROM_DIR.tmp/INSTALL/PPTP.EXE" ]] || fatal "Udpakket ISO mangler INSTALL/PPTP.EXE"
  [[ -f "$CDROM_DIR.tmp/PPTP.ORB" ]] || fatal "Udpakket ISO mangler PPTP.ORB"
  rm -rf "$CDROM_DIR"
  mv "$CDROM_DIR.tmp" "$CDROM_DIR"
}

repair_broken_prefix_if_needed() {
  if [[ -d "$WINEPREFIX_DIR" && ! -d "$WINEPREFIX_DIR/drive_c/windows" ]]; then
    local backup="${WINEPREFIX_DIR}.broken.$(date +%Y%m%d-%H%M%S)"
    log "Finder halvfærdig Wine-prefix uden drive_c/windows; flytter til $backup"
    mv "$WINEPREFIX_DIR" "$backup"
  fi
}

init_prefix() {
  export WINEPREFIX="$WINEPREFIX_DIR"
  export WINEDEBUG="$WINEDEBUG_VALUE"
  if [[ "$FORCE_WIN32" == "1" ]]; then
    export WINEARCH=win32
  fi
  mkdir -p "$(dirname "$WINEPREFIX_DIR")"
  if [[ ! -d "$WINEPREFIX_DIR/drive_c/windows/system32" ]]; then
    log "Initialiserer Wine-prefix: $WINEPREFIX_DIR"
    local status=0
    if command -v timeout >/dev/null 2>&1; then
      timeout "${WINEBOOT_TIMEOUT}s" "$WINE_BIN" wineboot -u || status=$?
    else
      "$WINE_BIN" wineboot -u || status=$?
    fi
    if [[ "$status" != 0 && -d "$WINEPREFIX_DIR/drive_c/windows/system32" ]]; then
      log "wineboot returnerede $status, men prefixen findes; stopper første-init processer og fortsætter"
      # Første Wine-init kan efterlade wineboot/rundll32-vinduer, især når vi
      # afbryder med timeout. Stop dem nu, ellers kan de blokere den efterfølgende
      # spilstarter og efterlade et generisk "Wine"-vindue i stedet for PPTP.EXE.
      if command -v timeout >/dev/null 2>&1; then
        timeout 15s "$WINE_BIN" wineserver -k >/dev/null 2>&1 || true
      else
        "$WINE_BIN" wineserver -k >/dev/null 2>&1 || true
      fi
    elif [[ "$status" != 0 ]]; then
      fatal "wineboot fejlede med status $status før prefixen var klar"
    fi
  fi
  [[ -d "$WINEPREFIX_DIR/drive_c/windows/system32" ]] || fatal "Wine-prefix blev ikke initialiseret korrekt"
  if command -v timeout >/dev/null 2>&1; then
    timeout 15s "$WINE_BIN" reg add 'HKCU\Software\Wine' /v Version /d win98 /f >/dev/null 2>&1 || true
  else
    "$WINE_BIN" reg add 'HKCU\Software\Wine' /v Version /d win98 /f >/dev/null 2>&1 || true
  fi
}

setup_cdrom_drive() {
  local drive_lower="${CD_DRIVE,,}"
  mkdir -p "$WINEPREFIX_DIR/dosdevices"
  rm -f "$WINEPREFIX_DIR/dosdevices/${drive_lower}:" "$WINEPREFIX_DIR/dosdevices/${drive_lower}::"
  ln -s "$CDROM_DIR" "$WINEPREFIX_DIR/dosdevices/${drive_lower}:"
  printf '%s\n' "$CD_LABEL" > "$CDROM_DIR/.windows-label" 2>/dev/null || true
  if command -v timeout >/dev/null 2>&1; then
    timeout 15s "$WINE_BIN" reg add 'HKCU\Software\Wine\Drives' /v "${drive_lower}:" /d cdrom /f >/dev/null 2>&1 || true
  else
    "$WINE_BIN" reg add 'HKCU\Software\Wine\Drives' /v "${drive_lower}:" /d cdrom /f >/dev/null 2>&1 || true
  fi
}

is_old_system_file() {
  case "${1^^}" in
    COMCTL32.DLL|COMDLG32.DLL|CRTDLL.DLL|LZ32.DLL|NETAPI32.DLL|OLECLI.DLL|OLECLI32.DLL|OLESVR32.DLL|RICHED32.DLL|SHELL32.DLL|VERSION.DLL|WINMM.DLL|WINMM16.DLL|WINSPOOL.DRV|WSOCK32.DLL|WINHLP32.EXE|WIN32S.EXE|W32S.386|W32SCOMB.DLL|W32SKRNL.DLL|W32SYS.DLL|WIN32S16.DLL|WING.DLL|WING32.DLL|WINGDE.DLL|WINGDIB.DRV|WINGPAL.WND)
      return 0 ;;
    *) return 1 ;;
  esac
}

manual_install_game() {
  local marker="$INSTALL_DIR/.pink-panther-clean-install-v2"
  if [[ -f "$INSTALLED_EXE" && -f "$marker" ]]; then
    return 0
  fi
  log "Laver clean runtime-install til: $INSTALL_DIR"
  rm -rf "$INSTALL_DIR.tmp"
  mkdir -p "$INSTALL_DIR.tmp"
  while IFS= read -r -d '' src; do
    local name
    name="$(basename "$src")"
    if is_old_system_file "$name"; then
      log "Udelader gammel systemfil: $name"
      continue
    fi
    cp -a "$src" "$INSTALL_DIR.tmp/"
  done < <(find "$CDROM_DIR/INSTALL" -mindepth 1 -maxdepth 1 -print0)

  # Disse root-filer findes også/kun i CD-roden og bliver slået op af spillet.
  for f in ALLSONGS.PTP PPTP.ORB LICENSE.TXT README.WRI; do
    [[ -e "$CDROM_DIR/$f" ]] && cp -f "$CDROM_DIR/$f" "$INSTALL_DIR.tmp/"
  done
  [[ -f "$INSTALL_DIR.tmp/PPTP.EXE" ]] || fatal "Clean install mangler PPTP.EXE"
  rm -rf "$INSTALL_DIR"
  mv "$INSTALL_DIR.tmp" "$INSTALL_DIR"
  touch "$marker"
}

extract_cdrom
repair_broken_prefix_if_needed
init_prefix
setup_cdrom_drive

if [[ "$MODE" == "prepare" ]]; then
  manual_install_game
  log "PREPARE OK"
  log "CD-ROM: $CDROM_DIR"
  log "Installeret exe: $INSTALLED_EXE"
  exit 0
fi

case "$MODE" in
  game|installed)
    manual_install_game
    cd "$INSTALL_DIR"
    TARGET='C:\Program Files\Pink Panther\PPTP.EXE'
    ;;
  cdgame|cdexe)
    cd "$CDROM_DIR/INSTALL"
    TARGET="${CD_DRIVE^^}:\\INSTALL\\PPTP.EXE"
    ;;
  teaser)
    cd "$CDROM_DIR"
    TARGET="${CD_DRIVE^^}:\\TEASER.EXE"
    ;;
  setup)
    cd "$CDROM_DIR"
    TARGET="${CD_DRIVE^^}:\\SETUP.EXE"
    ;;
  *)
    fatal "Ukendt PP_MODE: $MODE"
    ;;
esac

log "Starter mode=$MODE target=$TARGET"
if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
  "$WINE_BIN" explorer "/desktop=$DESKTOP_NAME,$DESKTOP_SIZE" "$TARGET"
else
  "$WINE_BIN" "$TARGET"
fi
# Behold processen under Lutris, hvis Wine launcher-vinduet returnerer tidligt.
"$WINE_BIN" wineserver -w 2>/dev/null || wineserver -w 2>/dev/null || true
