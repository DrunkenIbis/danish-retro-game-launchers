#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIP_PATH="${MM2_ZIP_PATH:-$SCRIPT_DIR/magnus-myggen-den-store-skattejagt.zip}"
BIN_PATH="${MM2_BIN_PATH:-$SCRIPT_DIR/MM2NORD.bin}"
CUE_PATH="${MM2_CUE_PATH:-$SCRIPT_DIR/MM2NORD.cue}"
ISO_PATH="${MM2_ISO_PATH:-$SCRIPT_DIR/MM2NORD.iso}"
CD_DIR="${MM2_CD_DIR:-$SCRIPT_DIR/cd-files}"
INSTALL_DIR="${MM2_INSTALL_DIR:-$SCRIPT_DIR/installed-dk}"
PREFIX="${WINEPREFIX:-${MM2_WINEPREFIX:-$SCRIPT_DIR/wineprefix32}}"
WINE_BIN="${MM2_WINE_BIN:-}"
CD_DRIVE="${MM2_CD_DRIVE:-d}"
DESKTOP_SIZE="${MM2_DESKTOP_SIZE:-800x600}"
# På Wayland/Xwayland kan det direkte MM2RUN-vindue køre med lyd men uden synligt billede.
# Wine Explorer virtual desktop giver et rigtigt fokuseret X11-vindue.
VIRTUAL_DESKTOP="${MM2_VIRTUAL_DESKTOP:-1}"
# game = bypass InstallShield og start den rigtige spil-exe direkte.
# launcher/setup = brug den originale CD launcher/installer til fejlsøgning.
MODE="${MM2_MODE:-game}"
RUN_INSTALLER="${MM2_RUN_INSTALLER:-0}"
DRY_RUN="${MM2_DRY_RUN:-0}"
FORCE_WIN32="${MM2_FORCE_WIN32:-1}"
WINVER="${MM2_WINVER:-win98}"

log() { printf '[MM2] %s\n' "$*"; }
fatal() { printf '[MM2] ERROR: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

choose_wine() {
  if [[ -n "$WINE_BIN" ]]; then
    command -v "$WINE_BIN" >/dev/null 2>&1 || fatal "MM2_WINE_BIN findes ikke: $WINE_BIN"
    printf '%s\n' "$WINE_BIN"
    return
  fi
  if command -v wine32 >/dev/null 2>&1; then
    printf 'wine32\n'
  elif command -v wine >/dev/null 2>&1; then
    printf 'wine\n'
  else
    fatal 'Mangler wine/wine32'
  fi
}

acquire_launch_lock() {
  if command -v flock >/dev/null 2>&1; then
    exec 9>"$SCRIPT_DIR/.mm2-launch.lock"
    flock -n 9 || fatal "MM2 kører allerede eller en gammel WineDbg-session hænger. Luk spillet/WineDbg først, eller kør: WINEPREFIX='$PREFIX' wineserver -k"
  fi
}

convert_bin_to_iso() {
  need_cmd python3
  log "Konverterer BIN/CUE til ISO: $ISO_PATH"
  python3 - "$BIN_PATH" "$ISO_PATH" <<'PY'
from pathlib import Path
import sys
src = Path(sys.argv[1])
out = Path(sys.argv[2])
sector = 2352
data_offset = 16
data_len = 2048
size = src.stat().st_size
if size % sector:
    raise SystemExit(f'BIN size {size} is not divisible by {sector}')
with src.open('rb') as f, out.open('wb') as g:
    for _ in range(size // sector):
        s = f.read(sector)
        g.write(s[data_offset:data_offset + data_len])
print(out)
PY
}

prepare_disc() {
  [[ -f "$ZIP_PATH" ]] || fatal "Zip-fil findes ikke: $ZIP_PATH"
  need_cmd 7z
  if [[ ! -f "$BIN_PATH" || ! -f "$CUE_PATH" ]]; then
    log "Udpakker MM2NORD.bin/cue fra zip"
    7z x -y -o"$SCRIPT_DIR" "$ZIP_PATH" MM2NORD.bin MM2NORD.cue >/dev/null
  fi
  [[ -f "$BIN_PATH" ]] || fatal "BIN mangler efter udpakning: $BIN_PATH"
  [[ -f "$CUE_PATH" ]] || fatal "CUE mangler efter udpakning: $CUE_PATH"
  if [[ ! -f "$ISO_PATH" ]]; then
    convert_bin_to_iso
  fi
  if [[ ! -d "$CD_DIR" || ! -f "$CD_DIR/AUTORUN.INF" ]]; then
    log "Udpakker ISO til CD mappe: $CD_DIR"
    rm -rf "$CD_DIR"
    mkdir -p "$CD_DIR"
    7z x -y -o"$CD_DIR" "$ISO_PATH" >/dev/null
  fi
  [[ -f "$CD_DIR/AUTORUN.INF" ]] || fatal "AUTORUN.INF blev ikke fundet i $CD_DIR"
  [[ -f "$CD_DIR/LAUNCHER.EXE" ]] || fatal "LAUNCHER.EXE blev ikke fundet i $CD_DIR"
  if command -v isoinfo >/dev/null 2>&1; then
    isoinfo -d -i "$ISO_PATH" 2>/dev/null | awk -F': ' '/Volume id:/ {print $2; found=1} END {if (!found) print "MM2NORD"}' > "$CD_DIR/.windows-label" || printf 'MM2NORD\n' > "$CD_DIR/.windows-label"
  else
    printf 'MM2NORD\n' > "$CD_DIR/.windows-label"
  fi
}

find_unshield() {
  if command -v unshield >/dev/null 2>&1; then
    printf '%s\n' "$(command -v unshield)"
    return 0
  fi
  return 1
}

prepare_manual_install() {
  if [[ -f "$INSTALL_DIR/MM2RUN.EXE" ]]; then
    return
  fi
  local unshield_bin=""
  unshield_bin="$(find_unshield || true)"
  [[ -n "$unshield_bin" ]] || fatal "Mangler unshield til manuel InstallShield-udpakning"
  log "Udpakker dansk spilprogram manuelt fra InstallShield CAB"
  rm -rf "$SCRIPT_DIR/manual-install" "$INSTALL_DIR"
  mkdir -p "$SCRIPT_DIR/manual-install" "$INSTALL_DIR"
  if [[ -d /home/test/.local/pkg/unshield-rpm/usr/lib64 ]]; then
    LD_LIBRARY_PATH=/home/test/.local/pkg/unshield-rpm/usr/lib64 "$unshield_bin" x -d "$SCRIPT_DIR/manual-install" "$CD_DIR/DATA1.CAB" >/dev/null
  else
    "$unshield_bin" x -d "$SCRIPT_DIR/manual-install" "$CD_DIR/DATA1.CAB" >/dev/null
  fi
  cp -f "$SCRIPT_DIR/manual-install/Program_files_DK/mm2run.exe" "$INSTALL_DIR/MM2RUN.EXE"
  cp -f "$SCRIPT_DIR/manual-install/Program_files/ui.ico" "$INSTALL_DIR/" 2>/dev/null || true
  cp -f "$SCRIPT_DIR/manual-install/Program_files/ii.ico" "$INSTALL_DIR/" 2>/dev/null || true
  [[ -f "$INSTALL_DIR/MM2RUN.EXE" ]] || fatal "Kunne ikke oprette $INSTALL_DIR/MM2RUN.EXE"
}

map_cdrom_drive() {
  local letter="$CD_DRIVE"
  mkdir -p "$PREFIX/dosdevices"
  ln -sfn "$CD_DIR" "$PREFIX/dosdevices/${letter}:"
  printf 'cdrom\n' > "$PREFIX/dosdevices/${letter}::"
}

patch_wine_registry_file() {
  local regfile="$1"
  [[ -f "$regfile" ]] || return 0
  python3 - "$regfile" "$CD_DRIVE" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
letter = sys.argv[2]
s = path.read_text(errors='replace')
remove = {
    '[SoftwareIVANOFF InteractiveMM2]',
    '[SoftwareWineDrives]',
    '[Software\\\\IVANOFF Interactive\\\\MM2]',
    '[Software\\\\Wine\\\\Drives]',
}
lines = s.splitlines()
out = []
skip = False
for line in lines:
    if line.startswith('['):
        skip = line.split(' ', 1)[0] in remove
    if not skip:
        out.append(line)
adds = []
if path.name == 'user.reg':
    adds.append(f'''[Software\\\\Wine\\\\Drives] 1779730000
#time=1dcec6700000000
"{letter}:"="cdrom"''')
adds.append(f'''[Software\\\\IVANOFF Interactive\\\\MM2] 1779730000
#time=1dcec6700000001
"mm2lng"="DK"
"Resource file"="{letter.upper()}:\\\\MM2"
"Resource local file"="{letter.upper()}:\\\\DK\\\\MM2LNG"
"SoundLevel"=dword:00000064
"BkgMusicOn"=dword:00000001
"WWWLinksOff"=dword:00000001''')
path.write_text('\n'.join(out).rstrip() + '\n\n' + '\n\n'.join(adds) + '\n')
PY
}

configure_wine_compat() {
  # MM2RUN.EXE is a Win95/98-era PE32 program. Wine's default Windows 10
  # compatibility can crash during early graphics/settings initialization.
  "$1" reg add 'HKCU\Software\Wine' /v Version /d "$WINVER" /f >/dev/null 2>&1 || true
}

prepare_prefix() {
  export WINEPREFIX="$PREFIX"
  if [[ "$FORCE_WIN32" == "1" && ! -d "$PREFIX" ]]; then
    export WINEARCH=win32
  fi
  if [[ ! -f "$PREFIX/system.reg" ]]; then
    log "Initialiserer Wine-prefix: $PREFIX"
    timeout "${MM2_WINEBOOT_TIMEOUT:-120s}" "$1" wineboot -u >/dev/null 2>&1 || true
    if command -v wineserver >/dev/null 2>&1; then
      WINEPREFIX="$PREFIX" wineserver -k >/dev/null 2>&1 || true
    fi
  fi
  map_cdrom_drive
  mkdir -p "$PREFIX/drive_c/ProgramData/IVANOFF/MM2/2.0"
  patch_wine_registry_file "$PREFIX/user.reg"
  patch_wine_registry_file "$PREFIX/system.reg"
  configure_wine_compat "$1"
}

run_windows_exe() {
  local wine="$1"
  local exe="$2"
  local cwd="$3"
  log "Starter $exe med $wine"
  cd "$cwd"
  if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
    exec "$wine" explorer "/desktop=MagnusMyggen2,$DESKTOP_SIZE" "$exe"
  else
    exec "$wine" "$exe"
  fi
}

main() {
  local wine
  wine="$(choose_wine)"
  if [[ "$DRY_RUN" == "1" ]]; then
    log "Dry-run"
    log "Mappe: $SCRIPT_DIR"
    log "Mode: $MODE"
    log "Zip: $ZIP_PATH"
    log "BIN: $BIN_PATH"
    log "CUE: $CUE_PATH"
    log "ISO: $ISO_PATH"
    log "CD mappe: $CD_DIR"
    log "Install mappe: $INSTALL_DIR"
    log "Wine: $wine"
    log "Prefix: $PREFIX"
    log "CD-ROM drev: ${CD_DRIVE}:"
    log "Virtual desktop: $VIRTUAL_DESKTOP ($DESKTOP_SIZE)"
    log "Wine Windows-version: $WINVER"
    exit 0
  fi

  acquire_launch_lock
  prepare_disc
  prepare_prefix "$wine"

  case "$MODE" in
    game)
      prepare_manual_install
      run_windows_exe "$wine" "$INSTALL_DIR/MM2RUN.EXE" "$INSTALL_DIR"
      ;;
    launcher)
      run_windows_exe "$wine" "${CD_DRIVE}:\\LAUNCHER.EXE" "$SCRIPT_DIR"
      ;;
    setup)
      run_windows_exe "$wine" "${CD_DRIVE}:\\SETUP.EXE" "$SCRIPT_DIR"
      ;;
    *)
      if [[ "$RUN_INSTALLER" == "1" ]]; then
        run_windows_exe "$wine" "${CD_DRIVE}:\\SETUP.EXE" "$SCRIPT_DIR"
      else
        fatal "Ukendt MM2_MODE=$MODE (brug game, launcher eller setup)"
      fi
      ;;
  esac
}

main "$@"
