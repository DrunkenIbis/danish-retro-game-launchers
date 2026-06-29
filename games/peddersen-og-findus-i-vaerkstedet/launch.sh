#!/usr/bin/env bash
set -Eeuo pipefail

# Peddersen og Findus i værkstedet (Gammafon, dansk/nordisk CD-ROM)
#
# Kompatibilitetsvalg:
# 1) Recipe-only stier: ISO'en læses fra local/sources/<game-id>/ eller
#    FINDUS1_ISO, mens CD-udpakning, Wine-prefix og manuel install skrives til
#    local/runtime/<game-id>/ eller FINDUS1_RUNTIME_DIR.
# 2) Spillet er en PE32 Macromedia Director 8.5 titel med 32-bit Xtras; brug
#    wine32/win32-prefix og Win98-kompatibilitet som stabil default.
# 3) Direkte D:\DATA\Findus1.exe viser kun dialogen "Findus1 skal installeres
#    først." Launcheren laver derfor en manuel runtime-install: DATA/ kopieres
#    til C:\Program Files\Findus1, Media/ kopieres med, og
#    HKLM\Software\Gammafon\Findus1 peger på den installerede Findus1.exe.
# 4) Den udpakkede CD mappes stadig som D: med label FINDUS1, så autorun/setup
#    modes og eventuelle CD-relative opslag har original kontekst.
# 5) 800x600 Wine desktop giver et synligt, kontrolleret vindue; selve spillet
#    tegner 640x480 indhold.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_NAME="peddersen-og-findus-i-vaerkstedet"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${FINDUS1_SOURCE_DIR:-$SOURCE_BASE/$PROJECT_NAME}"
RUNTIME_DIR="${FINDUS1_RUNTIME_DIR:-$RUNTIME_BASE/$PROJECT_NAME}"
ISO_PATH="${FINDUS1_ISO:-$SOURCE_DIR/Peddersen-og-Findus-i-vaerkstedet.iso}"
CDROM_DIR="${FINDUS1_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
WINEPREFIX_DIR="${FINDUS1_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}"
INSTALL_DIR="${FINDUS1_INSTALL_DIR:-$WINEPREFIX_DIR/drive_c/Program Files/Findus1}"

SEVENZ_BIN="${FINDUS1_SEVENZ_BIN:-7z}"
if [[ -n "${FINDUS1_WINE_BIN:-}" ]]; then
  WINE_BIN="$FINDUS1_WINE_BIN"
elif command -v wine32 >/dev/null 2>&1; then
  WINE_BIN="wine32"
else
  WINE_BIN="wine"
fi
WINEBOOT_TIMEOUT="${FINDUS1_WINEBOOT_TIMEOUT:-90}"
WINEDEBUG_VALUE="${FINDUS1_WINEDEBUG:--all}"
MODE="${FINDUS1_MODE:-${1:-game}}"
CD_DRIVE="${FINDUS1_CD_DRIVE:-d}"
CD_LABEL="${FINDUS1_CD_LABEL:-FINDUS1}"
DESKTOP_NAME="${FINDUS1_DESKTOP_NAME:-Findus1}"
DESKTOP_SIZE="${FINDUS1_DESKTOP_SIZE:-800x600}"
VIRTUAL_DESKTOP="${FINDUS1_VIRTUAL_DESKTOP:-1}"
FORCE_WIN32="${FINDUS1_FORCE_WIN32:-1}"
DRY_RUN="${FINDUS1_DRY_RUN:-0}"
LOCK_FILE="${FINDUS1_LOCK_FILE:-$RUNTIME_DIR/.launch.lock}"

log() { printf '[Findus1] %s\n' "$*"; }
fatal() { printf '[Findus1] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

usage() {
  cat <<EOF
Brug: ./launch.sh [game|prepare|cdgame|autorun|setup|settings|kill|dry-run]

Miljøvariabler:
  FINDUS1_MODE=game|prepare|cdgame|autorun|setup|settings|kill|dry-run
  FINDUS1_ISO=/sti/til/Peddersen-og-Findus-i-vaerkstedet.iso
  FINDUS1_SOURCE_DIR=/mappe/med ISO
  FINDUS1_RUNTIME_DIR=/runtime/mappe
  FINDUS1_WINEPREFIX=/runtime/wineprefix32
  FINDUS1_WINE_BIN=wine32|wine
  FINDUS1_VIRTUAL_DESKTOP=0|1
  FINDUS1_DESKTOP_SIZE=800x600
  FINDUS1_DRY_RUN=1

Private standardstier:
  ISO:     $ISO_PATH
  Runtime: $RUNTIME_DIR
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  ""|game|prepare|cdgame|autorun|setup|settings|kill|dry-run) ;;
  *) fatal "Ukendt argument: $1" ;;
esac
[[ "${1:-}" == "dry-run" ]] && DRY_RUN=1
[[ -n "${1:-}" && "${1:-}" != "dry-run" ]] && MODE="$1"

MAIN_EXE="$CDROM_DIR/DATA/Findus1.exe"
INSTALLED_EXE="$INSTALL_DIR/Findus1.exe"

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

acquire_launch_lock() {
  mkdir -p "$RUNTIME_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || fatal "Spillet kører allerede for denne runtime. Luk det, eller kør: FINDUS1_MODE=kill ./launch.sh"
  fi
}

kill_wine() {
  export WINEPREFIX="$WINEPREFIX_DIR"
  if command -v wineserver >/dev/null 2>&1; then
    wineserver -k >/dev/null 2>&1 || true
  else
    "$WINE_BIN" wineserver -k >/dev/null 2>&1 || true
  fi
  log "Wine-prefix stoppet: $WINEPREFIX_DIR"
}

extract_cdrom() {
  if [[ -f "$MAIN_EXE" && -f "$CDROM_DIR/autorun.inf" && -f "$CDROM_DIR/Media/start.dxr" ]]; then
    return 0
  fi
  [[ -f "$ISO_PATH" ]] || fatal "Kan ikke finde ISO: $ISO_PATH. Kør ./install.sh --download --no-launch eller sæt FINDUS1_ISO."
  log "Udpakker ISO til: $CDROM_DIR"
  rm -rf "$CDROM_DIR.tmp"
  mkdir -p "$CDROM_DIR.tmp"
  "$SEVENZ_BIN" x -y -o"$CDROM_DIR.tmp" "$ISO_PATH" >/dev/null
  [[ -f "$CDROM_DIR.tmp/DATA/Findus1.exe" ]] || fatal "Udpakket ISO mangler DATA/Findus1.exe"
  [[ -f "$CDROM_DIR.tmp/Media/start.dxr" ]] || fatal "Udpakket ISO mangler Media/start.dxr"
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
  if [[ "$FORCE_WIN32" == "1" && ! -f "$WINEPREFIX_DIR/system.reg" ]]; then
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
      timeout 15s "$WINE_BIN" wineserver -k >/dev/null 2>&1 || true
    elif [[ "$status" != 0 ]]; then
      fatal "wineboot fejlede med status $status før prefixen var klar"
    fi
  fi
  [[ -d "$WINEPREFIX_DIR/drive_c/windows/system32" ]] || fatal "Wine-prefix blev ikke initialiseret korrekt"
  timeout 20s "$WINE_BIN" reg add 'HKCU\Software\Wine' /v Version /d win98 /f >/dev/null 2>&1 || true
}

setup_cdrom_drive() {
  local drive_lower="${CD_DRIVE,,}"
  mkdir -p "$WINEPREFIX_DIR/dosdevices"
  rm -f "$WINEPREFIX_DIR/dosdevices/${drive_lower}:" "$WINEPREFIX_DIR/dosdevices/${drive_lower}::"
  ln -s "$CDROM_DIR" "$WINEPREFIX_DIR/dosdevices/${drive_lower}:"
  printf '%s\n' "$CD_LABEL" > "$CDROM_DIR/.windows-label" 2>/dev/null || true
  timeout 20s "$WINE_BIN" reg add 'HKCU\Software\Wine\Drives' /v "${drive_lower}:" /d cdrom /f >/dev/null 2>&1 || true
}

manual_install_game() {
  local marker="$INSTALL_DIR/.findus1-manual-install-v1"
  if [[ -f "$INSTALLED_EXE" && -f "$marker" && -d "$INSTALL_DIR/Media" ]]; then
    return 0
  fi
  log "Laver manuel runtime-install til: $INSTALL_DIR"
  rm -rf "$INSTALL_DIR.tmp"
  mkdir -p "$INSTALL_DIR.tmp"
  cp -a "$CDROM_DIR/DATA/." "$INSTALL_DIR.tmp/"
  cp -a "$CDROM_DIR/Media" "$INSTALL_DIR.tmp/"
  # Director 8 søger nogle ressourcer med lowercase media/ først. Windows er
  # case-insensitive, men host-filsystemet er ikke; symlinket undgår støjende
  # lookup-fejl uden at duplikere de store DXR/CXT-filer.
  ln -sfn Media "$INSTALL_DIR.tmp/media"
  [[ -f "$INSTALL_DIR.tmp/Findus1.exe" ]] || fatal "Manuel install mangler Findus1.exe"
  [[ -f "$INSTALL_DIR.tmp/Media/start.dxr" ]] || fatal "Manuel install mangler Media/start.dxr"
  rm -rf "$INSTALL_DIR"
  mv "$INSTALL_DIR.tmp" "$INSTALL_DIR"
  touch "$marker"
}

register_install_path() {
  local win_path='C:\Program Files\Findus1\Findus1.exe'
  timeout 20s "$WINE_BIN" reg add 'HKLM\Software\Gammafon\Findus1' /ve /t REG_SZ /d "$win_path" /f >/dev/null 2>&1 || true
}

run_windows_exe() {
  local target="$1" cwd="$2"
  export WINEPREFIX="$WINEPREFIX_DIR"
  export WINEDEBUG="$WINEDEBUG_VALUE"
  log "Starter mode=$MODE target=$target"
  cd "$cwd"
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    "$WINE_BIN" explorer "/desktop=$DESKTOP_NAME,$DESKTOP_SIZE" "$target"
  else
    "$WINE_BIN" "$target"
  fi
  "$WINE_BIN" wineserver -w 2>/dev/null || wineserver -w 2>/dev/null || true
}

if [[ "$MODE" == "kill" ]]; then
  kill_wine
  exit 0
fi

extract_cdrom
repair_broken_prefix_if_needed
init_prefix
setup_cdrom_drive

case "$MODE" in
  prepare)
    manual_install_game
    register_install_path
    log "PREPARE OK"
    log "CD-ROM: $CDROM_DIR"
    log "Installeret exe: $INSTALLED_EXE"
    ;;
  game|installed)
    manual_install_game
    register_install_path
    acquire_launch_lock
    run_windows_exe 'C:\Program Files\Findus1\Findus1.exe' "$INSTALL_DIR"
    ;;
  cdgame|cdexe)
    register_install_path
    acquire_launch_lock
    run_windows_exe "${CD_DRIVE^^}:\\DATA\\Findus1.exe" "$CDROM_DIR/DATA"
    ;;
  autorun)
    acquire_launch_lock
    run_windows_exe "${CD_DRIVE^^}:\\autorun\\Autorun.exe" "$CDROM_DIR/autorun"
    ;;
  setup)
    acquire_launch_lock
    run_windows_exe "${CD_DRIVE^^}:\\Installér Findus1.exe" "$CDROM_DIR"
    ;;
  settings)
    manual_install_game
    register_install_path
    acquire_launch_lock
    run_windows_exe 'C:\Program Files\Findus1\Indstillinger.exe' "$INSTALL_DIR"
    ;;
  *)
    fatal "Ukendt FINDUS1_MODE=$MODE (brug game, prepare, cdgame, autorun, setup, settings, kill eller dry-run)"
    ;;
esac
