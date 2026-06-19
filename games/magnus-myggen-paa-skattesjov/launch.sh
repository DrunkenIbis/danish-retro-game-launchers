#!/usr/bin/env bash
set -Eeuo pipefail

GAME_ID="magnus-myggen-paa-skattesjov"
GAME_TITLE="Magnus & Myggen: På Skattesjov"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${MM8_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${MM8_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
CUE_PATH="${MM8_CUE:-$SOURCE_DIR/SS12DK.cue}"
BIN_PATH="${MM8_BIN:-$SOURCE_DIR/SS12DK.bin}"
ISO_PATH="${MM8_ISO:-$SOURCE_DIR/SS12DK.iso}"
CDROM_DIR="${MM8_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
INSTALL_DIR="${MM8_INSTALL_DIR:-$RUNTIME_DIR/installed}"
PREFIX="${WINEPREFIX:-${MM8_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}}"
CD_DRIVE="${MM8_CD_DRIVE:-d}"
MODE="${MM8_MODE:-${1:-game}}"
WINE_BIN="${MM8_WINE_BIN:-${WINE_BIN:-}}"
WINVER="${MM8_WINVER:-win98}"
FORCE_WIN32="${MM8_FORCE_WIN32:-1}"
DESKTOP_SIZE="${MM8_DESKTOP_SIZE:-800x600}"
VIRTUAL_DESKTOP="${MM8_VIRTUAL_DESKTOP:-0}"
DRY_RUN="${MM8_DRY_RUN:-0}"
LOCK_FILE="${MM8_LOCK_FILE:-$RUNTIME_DIR/.launch.lock}"
WINEBOOT_TIMEOUT="${MM8_WINEBOOT_TIMEOUT:-60s}"
UNSHIELD_BIN="${MM8_UNSHIELD:-}"
UNSHIELD_LIBRARY_PATH="${MM8_UNSHIELD_LIBRARY_PATH:-}"

log() { printf '[MM8] %s\n' "$*"; }
fatal() { printf '[MM8] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

choose_wine() {
  if [[ -n "$WINE_BIN" ]]; then
    command -v "$WINE_BIN" >/dev/null 2>&1 || [[ -x "$WINE_BIN" ]] || fatal "MM8_WINE_BIN/WINE_BIN findes ikke: $WINE_BIN"
    printf '%s\n' "$WINE_BIN"
  elif command -v wine32 >/dev/null 2>&1; then
    printf 'wine32\n'
  elif command -v wine >/dev/null 2>&1; then
    printf 'wine\n'
  else
    fatal 'Mangler wine32/wine'
  fi
}

find_unshield() {
  if [[ -n "$UNSHIELD_BIN" ]]; then
    [[ -x "$UNSHIELD_BIN" ]] || fatal "MM8_UNSHIELD er ikke eksekverbar: $UNSHIELD_BIN"
    printf '%s\n' "$UNSHIELD_BIN"
    return 0
  fi
  if command -v unshield >/dev/null 2>&1; then
    command -v unshield
    return 0
  fi
  if [[ -x /home/test/.local/bin/unshield ]]; then
    printf '%s\n' /home/test/.local/bin/unshield
    return 0
  fi
  return 1
}

run_unshield() {
  local unshield="$1"; shift
  if [[ -n "$UNSHIELD_LIBRARY_PATH" ]]; then
    LD_LIBRARY_PATH="$UNSHIELD_LIBRARY_PATH${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$unshield" "$@"
  elif [[ "$unshield" == /home/test/.local/bin/unshield && -d /home/test/.local/pkg/unshield-rpm/usr/lib64 ]]; then
    LD_LIBRARY_PATH="/home/test/.local/pkg/unshield-rpm/usr/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" "$unshield" "$@"
  else
    "$unshield" "$@"
  fi
}

convert_bin_cue_to_iso_if_needed() {
  if [[ -f "$ISO_PATH" ]]; then
    return 0
  fi
  [[ -f "$CUE_PATH" ]] || return 1
  [[ -f "$BIN_PATH" ]] || return 1
  if ! grep -Eq 'TRACK[[:space:]]+01[[:space:]]+MODE2/2352' "$CUE_PATH"; then
    fatal "CUE er ikke den forventede single-track MODE2/2352 disk: $CUE_PATH"
  fi
  need_cmd python3
  log "Konverterer BIN/CUE MODE2/2352 til ISO: $ISO_PATH"
  mkdir -p "$(dirname "$ISO_PATH")"
  python3 - "$BIN_PATH" "$ISO_PATH.tmp" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1])
dst = Path(sys.argv[2])
sector_size = 2352
payload_start = 24
payload_end = payload_start + 2048
count = 0
with src.open('rb') as f, dst.open('wb') as out:
    while True:
        sector = f.read(sector_size)
        if not sector:
            break
        if len(sector) != sector_size:
            raise SystemExit(f'partial trailing sector: {len(sector)} bytes')
        out.write(sector[payload_start:payload_end])
        count += 1
if count == 0:
    raise SystemExit('no sectors converted')
PY
  mv -f "$ISO_PATH.tmp" "$ISO_PATH"
}

iso_volume_label() {
  if command -v isoinfo >/dev/null 2>&1 && [[ -f "$ISO_PATH" ]]; then
    isoinfo -d -i "$ISO_PATH" 2>/dev/null | awk -F': ' '/Volume id:/ {print $2; found=1} END {if (!found) print "SS12DK"}'
  else
    printf 'SS12DK\n'
  fi
}

prepare_cdrom() {
  if [[ ! -f "$CDROM_DIR/AUTORUN.INF" || ! -f "$CDROM_DIR/DATA1.CAB" || ! -f "$CDROM_DIR/MMSUPER.EXE" ]]; then
    convert_bin_cue_to_iso_if_needed || true
    [[ -f "$ISO_PATH" ]] || fatal "ISO blev ikke fundet: $ISO_PATH. Kør ./install.sh --download --no-launch først, eller sæt MM8_ISO/MM8_BIN/MM8_CUE."
    need_cmd 7z
    log "Udpakker ISO til runtime CD-ROM: $CDROM_DIR"
    rm -rf "$CDROM_DIR"
    mkdir -p "$CDROM_DIR"
    7z x -y -o"$CDROM_DIR" "$ISO_PATH" >/dev/null
  fi
  [[ -f "$CDROM_DIR/AUTORUN.INF" ]] || fatal "AUTORUN.INF mangler i $CDROM_DIR"
  [[ -f "$CDROM_DIR/LAUNCHER.EXE" ]] || fatal "LAUNCHER.EXE mangler i $CDROM_DIR"
  [[ -f "$CDROM_DIR/MMSUPER.EXE" ]] || fatal "MMSUPER.EXE mangler i $CDROM_DIR"
  [[ -f "$CDROM_DIR/DATA1.CAB" ]] || fatal "DATA1.CAB mangler i $CDROM_DIR"
  iso_volume_label > "$CDROM_DIR/.windows-label"
}

prepare_manual_install() {
  if [[ -x "$INSTALL_DIR/mm8main.exe" && -f "$INSTALL_DIR/mydlg.cxt" && -d "$INSTALL_DIR/xtras" ]]; then
    return 0
  fi
  local unshield
  unshield="$(find_unshield || true)"
  [[ -n "$unshield" ]] || fatal "Mangler unshield til at udpakke InstallShield CAB manuelt"
  log "Udpakker Director-spillet manuelt fra DATA1.CAB"
  rm -rf "$RUNTIME_DIR/unshield" "$INSTALL_DIR"
  mkdir -p "$RUNTIME_DIR/unshield" "$INSTALL_DIR"
  run_unshield "$unshield" x -d "$RUNTIME_DIR/unshield" "$CDROM_DIR/DATA1.CAB" >/dev/null
  [[ -f "$RUNTIME_DIR/unshield/Files_All_DK/mm8main.exe" ]] || fatal "mm8main.exe blev ikke fundet efter unshield-udpakning"
  cp -a "$RUNTIME_DIR/unshield/Files_All_DK/." "$INSTALL_DIR/"
  mkdir -p "$INSTALL_DIR/xtras"
  cp -a "$RUNTIME_DIR/unshield/Files_All/Xtras/." "$INSTALL_DIR/xtras/"
  cp -f "$RUNTIME_DIR/unshield/Files_All/UI.ICO" "$INSTALL_DIR/" 2>/dev/null || true
  chmod +x "$INSTALL_DIR/mm8main.exe" 2>/dev/null || true
  [[ -f "$INSTALL_DIR/mydlg.cxt" ]] || fatal "mydlg.cxt mangler i install-mappen"
}

copy_install_to_c_drive() {
  local c_game_dir="$PREFIX/drive_c/Skattesjov"
  if [[ -x "$c_game_dir/mm8main.exe" && -f "$c_game_dir/mydlg.cxt" && -d "$c_game_dir/xtras" ]]; then
    return 0
  fi
  log "Kopierer runtime til C:\\Skattesjov"
  rm -rf "$c_game_dir"
  mkdir -p "$PREFIX/drive_c"
  cp -a "$INSTALL_DIR" "$c_game_dir"
}

prepare_prefix() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  mkdir -p "$(dirname "$PREFIX")"
  if [[ "$FORCE_WIN32" == "1" && ! -f "$PREFIX/system.reg" ]]; then
    export WINEARCH=win32
  fi
  if [[ ! -f "$PREFIX/system.reg" ]]; then
    log "Initialiserer Wine-prefix: $PREFIX"
    timeout "$WINEBOOT_TIMEOUT" "$wine" wineboot -u >/dev/null 2>&1 || true
    command -v wineserver >/dev/null 2>&1 && WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
  fi
  mkdir -p "$PREFIX/dosdevices"
  rm -f "$PREFIX/dosdevices/${CD_DRIVE}:" "$PREFIX/dosdevices/${CD_DRIVE}::"
  ln -sfn "$CDROM_DIR" "$PREFIX/dosdevices/${CD_DRIVE}:"
  "$wine" reg add 'HKCU\Software\Wine' /v Version /d "$WINVER" /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKCU\Software\Wine\Drives' /v "${CD_DRIVE}:" /d cdrom /f >/dev/null 2>&1 || true

  # InstallShield's registry footprint is useful for SuperStarter discovery, but
  # it does not unlock the shipped trial/SuperStarter gate.
  "$wine" reg add 'HKLM\Software\IVANOFF Interactive\MM8' /v AppPath /t REG_SZ /d 'C:\Skattesjov' /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKLM\Software\IVANOFF Interactive\MM8' /v Language /t REG_SZ /d DK /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKLM\Software\IVANOFF Interactive\MM8' /v netgame /t REG_SZ /d 0 /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKLM\Software\IVANOFF Interactive\superstarter' /v SourcePath /t REG_SZ /d "${CD_DRIVE}:\\" /f >/dev/null 2>&1 || true
}

acquire_launch_lock() {
  mkdir -p "$RUNTIME_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || fatal "På Skattesjov kører allerede for dette prefix. Luk spillet, eller kør: MM8_MODE=kill ./launch.sh"
  fi
}

run_game() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  export WINEDEBUG="${WINEDEBUG:--all}"
  cd "$PREFIX/drive_c/Skattesjov"
  log "Starter mm8main.exe fra C:\\Skattesjov"
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    exec "$wine" explorer "/desktop=Skattesjov,$DESKTOP_SIZE" 'C:\Skattesjov\mm8main.exe'
  else
    exec "$wine" 'C:\Skattesjov\mm8main.exe'
  fi
}

run_cd_exe() {
  local wine="$1" exe="$2"
  export WINEPREFIX="$PREFIX"
  cd "$CDROM_DIR"
  log "Starter ${CD_DRIVE}:\\$exe fra CD-ROM runtime"
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    exec "$wine" explorer "/desktop=Skattesjov,$DESKTOP_SIZE" "${CD_DRIVE}:\\$exe"
  else
    exec "$wine" "${CD_DRIVE}:\\$exe"
  fi
}

print_dry_run() {
  local wine="$1"
  log "Dry-run"
  log "Mode: $MODE"
  log "CUE: $CUE_PATH"
  log "BIN: $BIN_PATH"
  log "ISO: $ISO_PATH"
  log "CD-ROM runtime: $CDROM_DIR"
  log "Install runtime: $INSTALL_DIR"
  log "Wine-prefix: $PREFIX"
  log "Wine: $wine"
  log "CD-drev: ${CD_DRIVE}:"
  log "Winver: $WINVER"
  log "Virtual desktop: $VIRTUAL_DESKTOP ($DESKTOP_SIZE)"
}

main() {
  local wine
  wine="$(choose_wine)"
  if [[ "$DRY_RUN" == "1" || "$MODE" == "dry-run" ]]; then
    print_dry_run "$wine"
    exit 0
  fi
  if [[ "$MODE" == "kill" ]]; then
    WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
    exit 0
  fi

  acquire_launch_lock
  prepare_cdrom
  case "$MODE" in
    prepare)
      prepare_manual_install
      prepare_prefix "$wine"
      copy_install_to_c_drive
      log "Runtime er klar."
      ;;
    game)
      prepare_manual_install
      prepare_prefix "$wine"
      copy_install_to_c_drive
      run_game "$wine"
      ;;
    launcher|cdmenu)
      prepare_prefix "$wine"
      run_cd_exe "$wine" 'LAUNCHER.EXE'
      ;;
    superstarter)
      prepare_prefix "$wine"
      run_cd_exe "$wine" 'MMSUPER.EXE'
      ;;
    setup)
      prepare_prefix "$wine"
      run_cd_exe "$wine" 'SETUP.EXE'
      ;;
    *)
      fatal "Ukendt MM8_MODE=$MODE (brug game, prepare, launcher, superstarter, setup, dry-run eller kill)"
      ;;
  esac
}

main "$@"
