#!/usr/bin/env bash
set -Eeuo pipefail

# Den Lyserøde Panter: Hokus Pokus Panter
# Recipe-only launcher: uses a private ISO under local/sources, prepares runtime
# under local/runtime, maps the extracted CD as Wine drive D:, and starts the
# Win32 game executable from a clean install copy without bundled Win95 system DLLs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PROJECT_NAME="den-lyseroede-panter-hokus-pokus-panter"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${HPP_SOURCE_DIR:-$SOURCE_BASE/$PROJECT_NAME}"
RUNTIME_DIR="${HPP_RUNTIME_DIR:-$RUNTIME_BASE/$PROJECT_NAME}"
ISO_PATH="${HPP_ISO:-$SOURCE_DIR/Panter.iso}"
CDROM_DIR="${HPP_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
WINEPREFIX_DIR="${HPP_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}"
INSTALL_DIR="${HPP_INSTALL_DIR:-$WINEPREFIX_DIR/drive_c/HokusPokusPanter}"

SEVENZ_BIN="${HPP_SEVENZ_BIN:-7z}"
if command -v wine32 >/dev/null 2>&1; then
  WINE_BIN="${HPP_WINE_BIN:-wine32}"
else
  WINE_BIN="${HPP_WINE_BIN:-wine}"
fi
WINEBOOT_TIMEOUT="${HPP_WINEBOOT_TIMEOUT:-90}"
WINEDEBUG_VALUE="${HPP_WINEDEBUG:--all}"
MODE="${HPP_MODE:-game}"
CD_DRIVE="${HPP_CD_DRIVE:-d}"
CD_LABEL="${HPP_CD_LABEL:-PANTER}"
DESKTOP_NAME="${HPP_DESKTOP_NAME:-HokusPokusPanter}"
DESKTOP_SIZE="${HPP_DESKTOP_SIZE:-640x480}"
VIRTUAL_DESKTOP="${HPP_VIRTUAL_DESKTOP:-1}"
FORCE_WIN32="${HPP_FORCE_WIN32:-1}"
DRY_RUN="${HPP_DRY_RUN:-0}"

log() { printf '[Hokus Pokus Panter] %s\n' "$*"; }
fatal() { printf '[Hokus Pokus Panter] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

usage() {
  cat <<EOF
Brug: ./launch.sh

Miljøvariabler:
  HPP_MODE=game|prepare|teaser|setup|cdgame|kill  (default: game)
  HPP_ISO=/sti/til/Panter.iso
  HPP_SOURCE_DIR=/mappe/med/Panter.iso
  HPP_RUNTIME_DIR=/runtime/mappe
  HPP_WINEPREFIX=/runtime/wineprefix32
  HPP_VIRTUAL_DESKTOP=0|1
  HPP_DESKTOP_SIZE=640x480
  HPP_DRY_RUN=1

Private standardstier:
  ISO:     $ISO_PATH
  Runtime: $RUNTIME_DIR
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  "") ;;
  *) fatal "Ukendt argument: $1 (brug HPP_MODE=... for launch-mode)" ;;
esac

need_cmd "$SEVENZ_BIN"
need_cmd "$WINE_BIN"

MAIN_EXE="$CDROM_DIR/INSTALL/Hpp.exe"
INSTALLED_EXE="$INSTALL_DIR/Hpp.exe"

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
  if [[ -f "$MAIN_EXE" && -f "$CDROM_DIR/AUTORUN.INF" && -f "$CDROM_DIR/hpp.orb" ]]; then
    return 0
  fi
  [[ -f "$ISO_PATH" ]] || fatal "Kan ikke finde ISO: $ISO_PATH. Kør ./install.sh --download --no-launch eller sæt HPP_ISO."
  log "Udpakker ISO til: $CDROM_DIR"
  rm -rf "$CDROM_DIR.tmp"
  mkdir -p "$CDROM_DIR.tmp"
  "$SEVENZ_BIN" x -y -o"$CDROM_DIR.tmp" "$ISO_PATH"
  [[ -f "$CDROM_DIR.tmp/INSTALL/Hpp.exe" ]] || fatal "Udpakket ISO mangler INSTALL/Hpp.exe"
  [[ -f "$CDROM_DIR.tmp/hpp.orb" ]] || fatal "Udpakket ISO mangler hpp.orb"
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
      log "wineboot returnerede $status, men prefixen findes; fortsætter"
      # Første Wine init kan have langsomme setupapi/rundll32-hjælpere. Undgå at
      # blokere launcheren på wineserver -k her; næste Wine-kald kan genbruge den
      # prefix, der allerede har et C:-drev.
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
  local marker="$INSTALL_DIR/.hokus-pokus-panter-clean-install-v2"
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

  # Disse root-filer findes også/kun i CD-roden og kan blive slået op af spillet.
  for f in hpp.orb SONGS.SON README.TXT LICENSE.TXT; do
    [[ -e "$CDROM_DIR/$f" ]] && cp -f "$CDROM_DIR/$f" "$INSTALL_DIR.tmp/"
  done
  [[ -f "$INSTALL_DIR.tmp/Hpp.exe" ]] || fatal "Clean install mangler Hpp.exe"
  patch_hpp_exe_sizeofimage "$INSTALL_DIR.tmp/Hpp.exe"
  rm -rf "$INSTALL_DIR"
  mv "$INSTALL_DIR.tmp" "$INSTALL_DIR"
  touch "$marker"
}

patch_hpp_exe_sizeofimage() {
  local exe="$1"
  python3 - "$exe" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[1])
b = bytearray(p.read_bytes())
if b[0:2] != b'MZ':
    raise SystemExit('not an MZ executable')
pe = int.from_bytes(b[0x3c:0x40], 'little')
if b[pe:pe+4] != b'PE\0\0':
    raise SystemExit('not a PE executable')
coff = pe + 4
sections = int.from_bytes(b[coff+2:coff+4], 'little')
opt_size = int.from_bytes(b[coff+16:coff+18], 'little')
opt = coff + 20
if int.from_bytes(b[opt:opt+2], 'little') != 0x10b:
    raise SystemExit('not a PE32 executable')
section_table = opt + opt_size
section_alignment = int.from_bytes(b[opt+32:opt+36], 'little')
old_size = int.from_bytes(b[opt+56:opt+60], 'little')
end = 0
for i in range(sections):
    off = section_table + i * 40
    virtual_size = int.from_bytes(b[off+8:off+12], 'little')
    virtual_address = int.from_bytes(b[off+12:off+16], 'little')
    raw_size = int.from_bytes(b[off+16:off+20], 'little')
    end = max(end, virtual_address + max(virtual_size, raw_size))
new_size = ((end + section_alignment - 1) // section_alignment) * section_alignment
# Hpp.exe on this disc declares SizeOfImage=0xb3000, but .rsrc extends to
# 0xb83d4. Wine 11 rejects that with c000007b. Windows accepted it, so make the
# installed runtime copy's PE header internally consistent; do not touch the ISO.
if old_size < new_size:
    b[opt+56:opt+60] = new_size.to_bytes(4, 'little')
    p.write_bytes(b)
    print(f'Patched Hpp.exe SizeOfImage: 0x{old_size:x} -> 0x{new_size:x}')
else:
    print(f'Hpp.exe SizeOfImage OK: 0x{old_size:x}')
PY
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
  game)
    manual_install_game
    cd "$INSTALL_DIR"
    TARGET='C:\HokusPokusPanter\Hpp.exe'
    ;;
  cdgame)
    cd "$CDROM_DIR/INSTALL"
    TARGET="${CD_DRIVE^^}:\\INSTALL\\Hpp.exe"
    ;;
  teaser)
    cd "$CDROM_DIR"
    TARGET="${CD_DRIVE^^}:\\teaser.exe"
    ;;
  setup)
    cd "$CDROM_DIR"
    TARGET="${CD_DRIVE^^}:\\setup.exe"
    ;;
  *)
    fatal "Ukendt HPP_MODE: $MODE"
    ;;
esac

log "Starter mode=$MODE target=$TARGET"
if [[ "$VIRTUAL_DESKTOP" == "1" ]]; then
  exec "$WINE_BIN" explorer "/desktop=$DESKTOP_NAME,$DESKTOP_SIZE" "$TARGET"
else
  exec "$WINE_BIN" "$TARGET"
fi
