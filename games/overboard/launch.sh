#!/usr/bin/env bash
set -Eeuo pipefail

GAME_ID="overboard"
GAME_TITLE="Overboard! / Shipwreckers!"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${OVERBOARD_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${OVERBOARD_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ZIP_PATH="${OVERBOARD_ZIP:-$SOURCE_DIR/OVERBOARD.zip}"
ISO_PATH="${OVERBOARD_ISO:-$SOURCE_DIR/OVERBOARD.iso}"
BIN_PATH="${OVERBOARD_BIN:-$SOURCE_DIR/OVERBOARD.bin}"
CUE_PATH="${OVERBOARD_CUE:-$SOURCE_DIR/OVERBOARD.cue}"
CD_DIR="${OVERBOARD_CD_DIR:-$RUNTIME_DIR/cdrom}"
PREFIX="${WINEPREFIX:-${OVERBOARD_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}}"
INSTALL_DIR="${OVERBOARD_INSTALL_DIR:-$PREFIX/drive_c/Overboard}"
WINE_BIN="${OVERBOARD_WINE_BIN:-}"
CD_DRIVE="${OVERBOARD_CD_DRIVE:-d}"
MODE="${OVERBOARD_MODE:-${1:-game}}"
DRY_RUN="${OVERBOARD_DRY_RUN:-0}"
FORCE_WIN32="${OVERBOARD_FORCE_WIN32:-1}"
WINVER="${OVERBOARD_WINVER:-win98}"
WINEBOOT_TIMEOUT="${OVERBOARD_WINEBOOT_TIMEOUT:-90s}"
LOCK_FILE="${OVERBOARD_LOCK_FILE:-$RUNTIME_DIR/.launch.lock}"
DESKTOP_SIZE="${OVERBOARD_DESKTOP_SIZE:-800x600}"
VIRTUAL_DESKTOP="${OVERBOARD_VIRTUAL_DESKTOP:-1}"
LOGDIR="${OVERBOARD_LOGDIR:-$RUNTIME_DIR/logs}"
MEDIA_MODE="${OVERBOARD_MEDIA_MODE:-cuebin}"
LOOP_DEVICE=""

log() { printf '[Overboard] %s\n' "$*"; }
fatal() { printf '[Overboard] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

choose_wine() {
  if [[ -n "$WINE_BIN" ]]; then
    command -v "$WINE_BIN" >/dev/null 2>&1 || [[ -x "$WINE_BIN" ]] || fatal "OVERBOARD_WINE_BIN findes ikke: $WINE_BIN"
    printf '%s\n' "$WINE_BIN"
  elif command -v wine32 >/dev/null 2>&1; then
    printf 'wine32\n'
  elif command -v wine >/dev/null 2>&1; then
    printf 'wine\n'
  else
    fatal 'Mangler wine32/wine'
  fi
}

acquire_launch_lock() {
  mkdir -p "$RUNTIME_DIR"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$LOCK_FILE"
    flock -n 9 || fatal "Overboard kører allerede for dette prefix. Luk spillet, eller kør: OVERBOARD_MODE=kill ./launch.sh"
  fi
}

extract_original_bin_cue_if_needed() {
  if [[ -f "$BIN_PATH" && -f "$CUE_PATH" ]]; then
    return 0
  fi
  [[ -f "$ZIP_PATH" ]] || return 1
  need_cmd unzip
  mkdir -p "$SOURCE_DIR"
  log "Udpakker originale BIN/CUE til kildemappen"
  unzip -q -o "$ZIP_PATH" OVERBOARD.bin OVERBOARD.cue -d "$SOURCE_DIR"
  [[ -f "$BIN_PATH" && -f "$CUE_PATH" ]]
}

convert_zip_bin_cue_to_iso_if_needed() {
  [[ -f "$ISO_PATH" ]] && return 0
  [[ -f "$ZIP_PATH" ]] || return 1
  need_cmd unzip
  need_cmd python3
  local work="$RUNTIME_DIR/bin-cue-extract"
  local cue="$work/OVERBOARD.cue"
  local bin="$work/OVERBOARD.bin"
  rm -rf "$work"
  mkdir -p "$work" "$(dirname "$ISO_PATH")"
  log "Udpakker BIN/CUE fra ZIP og konverterer første MODE2/2352 data-track"
  unzip -q -o "$ZIP_PATH" OVERBOARD.bin OVERBOARD.cue -d "$work"
  python3 - "$cue" "$bin" "$ISO_PATH.tmp" <<'PY'
from pathlib import Path
import re
import sys
cue = Path(sys.argv[1])
bin_path = Path(sys.argv[2])
out_path = Path(sys.argv[3])
text = cue.read_text(errors='replace')
if not re.search(r'TRACK\s+01\s+MODE2/2352', text, re.I):
    raise SystemExit('expected TRACK 01 MODE2/2352')
match = re.search(r'TRACK\s+02\s+AUDIO\s+INDEX\s+00\s+(\d+):(\d+):(\d+)', text, re.I | re.S)
if not match:
    match = re.search(r'TRACK\s+02\s+AUDIO\s+INDEX\s+01\s+(\d+):(\d+):(\d+)', text, re.I | re.S)
if not match:
    raise SystemExit('could not find TRACK 02 start')
minutes, seconds, frames = map(int, match.groups())
data_sectors = ((minutes * 60) + seconds) * 75 + frames
with bin_path.open('rb') as src, out_path.open('wb') as dst:
    for i in range(data_sectors):
        sector = src.read(2352)
        if len(sector) != 2352:
            raise SystemExit(f'partial sector {i}: {len(sector)}')
        dst.write(sector[24:2072])
with out_path.open('r+b') as iso:
    for descriptor_sector in range(16, 32):
        iso.seek(descriptor_sector * 2048)
        header = iso.read(8)
        if len(header) < 8 or header[1:6] != b'CD001':
            continue
        dtype = header[0]
        if dtype in (1, 2):
            iso.seek(descriptor_sector * 2048 + 80)
            iso.write(data_sectors.to_bytes(4, 'little'))
            iso.write(data_sectors.to_bytes(4, 'big'))
        if dtype == 255:
            break
PY
  mv -f "$ISO_PATH.tmp" "$ISO_PATH"
  rm -rf "$work"
}

prepare_original_loop_device() {
  [[ "$MEDIA_MODE" == "cuebin" ]] || return 1
  extract_original_bin_cue_if_needed || return 1
  command -v udisksctl >/dev/null 2>&1 || return 1
  command -v losetup >/dev/null 2>&1 || return 1

  local existing setup_out dev
  existing="$(losetup -j "$BIN_PATH" | awk -F: 'NR==1 {print $1}')"
  if [[ -n "$existing" ]]; then
    dev="$existing"
  else
    setup_out="$(udisksctl loop-setup -f "$BIN_PATH" 2>/dev/null || true)"
    dev="$(printf '%s\n' "$setup_out" | sed -n "s/.* as \(\/dev\/loop[0-9]*\).*/\1/p" | tail -1)"
  fi
  [[ -n "${dev:-}" && -b "$dev" ]] || return 1
  LOOP_DEVICE="$dev"
  log "Bruger original BIN som backing device for Wine CD-ROM: $BIN_PATH ($LOOP_DEVICE)"
}

prepare_disc() {
  extract_original_bin_cue_if_needed || true
  prepare_original_loop_device || true
  if [[ ! -f "$CD_DIR/OB.EXE" || ! -f "$CD_DIR/RES.RDA" || ! -f "$CD_DIR/AUTORUN.INF" ]]; then
    convert_zip_bin_cue_to_iso_if_needed || true
    [[ -f "$ISO_PATH" ]] || fatal "ISO mangler: $ISO_PATH. Kør ./install.sh --download --no-launch, eller sæt OVERBOARD_ISO/OVERBOARD_ZIP."
    need_cmd 7z
    log "Udpakker data-track ISO til runtime CD-ROM: $CD_DIR"
    rm -rf "$CD_DIR"
    mkdir -p "$CD_DIR" "$LOGDIR"
    7z x -y -o"$CD_DIR" "$ISO_PATH" >"$LOGDIR/extract.log"
  fi
  [[ -f "$CD_DIR/OB.EXE" ]] || fatal "OB.EXE blev ikke fundet i $CD_DIR"
  [[ -f "$CD_DIR/RES.RDA" && -f "$CD_DIR/RES.RDR" && -f "$CD_DIR/RES.RDT" ]] || fatal "RES.RD* resource-filer mangler i $CD_DIR"
  printf 'OVERBOARD\n' > "$CD_DIR/.windows-label"
}

prepare_prefix() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  export TMPDIR="${TMPDIR:-/var/tmp}"
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
  ln -s "$CD_DIR" "$PREFIX/dosdevices/${CD_DRIVE}:"
  if [[ -n "$LOOP_DEVICE" && -b "$LOOP_DEVICE" ]]; then
    ln -s "$LOOP_DEVICE" "$PREFIX/dosdevices/${CD_DRIVE}::"
  fi
  "$wine" reg add 'HKCU\Software\Wine\Drives' /v "${CD_DRIVE}:" /d cdrom /f >/dev/null 2>&1 || true
  "$wine" reg add 'HKCU\Software\Wine' /v Version /d "$WINVER" /f >/dev/null 2>&1 || true
}

prepare_manual_install() {
  # OB.EXE can run from the disc, but it still checks Psygnosis installer
  # registry state. Without these keys it shows:
  # "Overboard! has not been installed properly".
  mkdir -p "$INSTALL_DIR"
  for f in OB.EXE OB.CFG S3DETDLL.DLL LANG.DAT OS.DAT; do
    if [[ -f "$CD_DIR/$f" ]]; then
      cp -f "$CD_DIR/$f" "$INSTALL_DIR/$f"
    fi
  done
  [[ -f "$INSTALL_DIR/OB.EXE" ]] || fatal "Kunne ikke forberede installeret OB.EXE i $INSTALL_DIR"
}

register_install_paths() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  local install_win install_win_slash resource_win fmv_win exe_win
  install_win="$($wine winepath -w "$INSTALL_DIR")"
  install_win_slash="${install_win}\\\\"
  resource_win="$($wine winepath -w "$CD_DIR")"
  fmv_win="$resource_win"
  exe_win="$install_win\\\\OB.EXE"

  # Keep the registry setup minimal and evidence-based. Earlier experiments that
  # added extra E:/F: CD-ROM mappings and MCI overrides did not satisfy the
  # game's CD validator and could confuse future debugging.
  "$wine" reg add 'HKCU\Software\Wine' /v 'Version' /d "$WINVER" /f >/dev/null 2>&1 || true
  for root in 'HKCU\\Software\\Psygnosis\\Studios\\Overboard!' 'HKLM\\Software\\Psygnosis\\Studios\\Overboard!'; do
    "$wine" reg add "$root" /v 'Path' /t REG_SZ /d "$install_win_slash" /f >/dev/null 2>&1 || true
    "$wine" reg add "$root" /v 'Exe Path' /t REG_SZ /d "$exe_win" /f >/dev/null 2>&1 || true
    "$wine" reg add "$root" /v 'Resource Path' /t REG_SZ /d "$resource_win" /f >/dev/null 2>&1 || true
    "$wine" reg add "$root" /v 'FMV Path' /t REG_SZ /d "$fmv_win" /f >/dev/null 2>&1 || true
  done
}

run_game() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  export TMPDIR="${TMPDIR:-/var/tmp}"

  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    exec "$wine" explorer "/desktop=Overboard,$DESKTOP_SIZE" "${CD_DRIVE^^}:\\OB.EXE"
  fi

  # Launch from the mapped CD root so the Windows current directory is D:\\,
  # not the Unix extraction path or the full EXE path (that causes
  # "Directory name invalid.").
  exec "$wine" cmd /c "cd /d ${CD_DRIVE^^}:\\ && OB.EXE"
}

run_autorun() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  export TMPDIR="${TMPDIR:-/var/tmp}"
  exec "$wine" cmd /c "cd /d ${CD_DRIVE^^}:\\ && AUTORUN.EXE"
}

run_setup() {
  local wine="$1"
  export WINEPREFIX="$PREFIX"
  export TMPDIR="${TMPDIR:-/var/tmp}"
  exec "$wine" cmd /c "cd /d ${CD_DRIVE^^}:\\ && SETUP.EXE"
}

if [[ "$DRY_RUN" == "1" ]]; then
  printf 'GAME_ID=%s\nSOURCE_DIR=%s\nRUNTIME_DIR=%s\nZIP_PATH=%s\nISO_PATH=%s\nCD_DIR=%s\nPREFIX=%s\nMODE=%s\n' \
    "$GAME_ID" "$SOURCE_DIR" "$RUNTIME_DIR" "$ZIP_PATH" "$ISO_PATH" "$CD_DIR" "$PREFIX" "$MODE"
  exit 0
fi

wine="$(choose_wine)"
case "$MODE" in
  kill)
    WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
    exit 0
    ;;
  prepare)
    acquire_launch_lock
    prepare_disc
    prepare_prefix "$wine"
    prepare_manual_install
    register_install_paths "$wine"
    log "Runtime klar: $RUNTIME_DIR"
    exec 9>&- 2>/dev/null || true
    ;;
  game)
    acquire_launch_lock
    prepare_disc
    prepare_prefix "$wine"
    prepare_manual_install
    register_install_paths "$wine"
    run_game "$wine"
    ;;
  autorun|cdmenu)
    acquire_launch_lock
    prepare_disc
    prepare_prefix "$wine"
    run_autorun "$wine"
    ;;
  setup)
    acquire_launch_lock
    prepare_disc
    prepare_prefix "$wine"
    run_setup "$wine"
    ;;
  *)
    fatal "Ukendt mode '$MODE' (brug game, autorun, setup, prepare eller kill)"
    ;;
esac
