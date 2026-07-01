#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GAME_ID="gys-paa-regneslottet"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${GYS_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${GYS_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ARCHIVE="${GYS_ARCHIVE:-${GYS_ZIP:-$SOURCE_DIR/Gys_Paa_Regneslottet.zip}}"
EXTRACTED_DIR="$RUNTIME_DIR/extracted"
GAME_ROOT="$EXTRACTED_DIR/Gys På Regneslottet"
DOSBOX_ROOT="$GAME_ROOT/SYSTEM/DOSBOX"
GAME_TREE="$DOSBOX_ROOT/GAME"
CDROM_ISO="$DOSBOX_ROOT/CDROM/CDROM.iso"
WINE_RUNTIME="$RUNTIME_DIR/wine95"
CDROM_DIR="$WINE_RUNTIME/cdrom"
PREFIX="${GYS_WINEPREFIX:-$WINE_RUNTIME/wineprefix32}"
LOGDIR="$RUNTIME_DIR/logs"
DESKTOP_SIZE="${GYS_WINE95_DESKTOP_SIZE:-1024x768}"
DESKTOP_NAME="${GYS_WINE95_DESKTOP_NAME:-GysWine95}"
WINEBIN="${GYS_WINEBIN:-}"
TARGET_EXE='C:\GILISOFT\GYS_CD\WNEWADDD.EXE'
TARGET_ARGS=("/CFG:C:\\GILISOFT\\GYS_CD\\WNEWADD.INI" "/startdir:D:\\DANSK")

mkdir -p "$RUNTIME_DIR" "$LOGDIR"

resolve_wine() {
  if [[ -n "$WINEBIN" ]]; then
    command -v "$WINEBIN" >/dev/null 2>&1 || { echo "GYS_WINEBIN findes ikke: $WINEBIN" >&2; exit 1; }
    return
  fi
  if command -v wine32 >/dev/null 2>&1; then
    WINEBIN=wine32
  elif command -v wine >/dev/null 2>&1; then
    WINEBIN=wine
  else
    echo "Wine mangler: installér wine32/wine, eller sæt GYS_WINEBIN=/sti/til/wine" >&2
    exit 1
  fi
}

extract_bundle_if_needed() {
  if [[ -f "$CDROM_ISO" && -f "$GAME_TREE/GILISOFT/GYS_CD/WNEWADDD.EXE" ]]; then
    return 0
  fi
  [[ -f "$ARCHIVE" ]] || { echo "Zip-arkiv mangler: $ARCHIVE" >&2; exit 1; }
  command -v unzip >/dev/null 2>&1 || { echo "unzip mangler; kan ikke udpakke $ARCHIVE" >&2; exit 1; }
  rm -rf "$EXTRACTED_DIR"
  mkdir -p "$EXTRACTED_DIR"
  set +e
  unzip -q "$ARCHIVE" -d "$EXTRACTED_DIR" >"$LOGDIR/wine95-extract-zip.log" 2>&1
  local unzip_status=$?
  set -e
  [[ -f "$CDROM_ISO" && -f "$GAME_TREE/GILISOFT/GYS_CD/WNEWADDD.EXE" ]] || {
    echo "Udpakning gav ikke forventet CDROM.iso og WNEWADDD.EXE" >&2
    exit 1
  }
  if [[ "$unzip_status" -ne 0 ]]; then
    echo "unzip returnerede status $unzip_status, men Wine95-required files findes; fortsætter. Se $LOGDIR/wine95-extract-zip.log" >&2
  fi
}

prepare_cdrom() {
  if [[ -f "$CDROM_DIR/DANSK/WNEWADDD.EXE" && -f "$CDROM_DIR/DANSK/ADD.A" ]]; then
    return 0
  fi
  command -v 7z >/dev/null 2>&1 || { echo "7z mangler; kan ikke udpakke CDROM.iso" >&2; exit 1; }
  rm -rf "$CDROM_DIR"
  mkdir -p "$CDROM_DIR"
  7z x -y -o"$CDROM_DIR" "$CDROM_ISO" >"$LOGDIR/wine95-extract-cdrom.log"
  [[ -f "$CDROM_DIR/DANSK/WNEWADDD.EXE" && -f "$CDROM_DIR/DANSK/ADD.A" ]] || {
    echo "CD-ROM runtime mangler DANSK/WNEWADDD.EXE eller DANSK/ADD.A efter udpakning" >&2
    exit 1
  }
}

prepare_prefix() {
  mkdir -p "$(dirname "$PREFIX")"
  local fresh_prefix=0
  if [[ ! -d "$PREFIX/drive_c/windows" ]]; then
    fresh_prefix=1
    export WINEARCH="${GYS_WINEARCH:-win32}"
  fi
  export WINEPREFIX="$PREFIX"
  if [[ "${GYS_WINE95_SKIP_WINEBOOT:-0}" != "1" && ( "$fresh_prefix" == 1 || "${GYS_WINE95_FORCE_WINEBOOT:-0}" == "1" ) ]]; then
    timeout "${GYS_WINEBOOT_TIMEOUT:-45}" "$WINEBIN" wineboot -u >/"$LOGDIR/wine95-wineboot.out" 2>"$LOGDIR/wine95-wineboot.err" || true
  fi
  "$WINEBIN" reg add 'HKCU\Software\Wine' /v Version /d win95 /f >/"$LOGDIR/wine95-reg.out" 2>"$LOGDIR/wine95-reg.err" || true
  mkdir -p "$PREFIX/dosdevices" "$PREFIX/drive_c/GILISOFT"
  rm -f "$PREFIX/dosdevices/d:" "$PREFIX/dosdevices/d::"
  ln -sfn "$CDROM_DIR" "$PREFIX/dosdevices/d:"
  printf 'GYS_CD\n' >"$CDROM_DIR/.windows-label" 2>/dev/null || true
  "$WINEBIN" reg add 'HKCU\Software\Wine\Drives' /v d: /d cdrom /f >>"$LOGDIR/wine95-reg.out" 2>>"$LOGDIR/wine95-reg.err" || true
  rm -rf "$PREFIX/drive_c/GILISOFT/GYS_CD"
  mkdir -p "$PREFIX/drive_c/GILISOFT"
  cp -a "$GAME_TREE/GILISOFT/GYS_CD" "$PREFIX/drive_c/GILISOFT/"

  # The game uses Microsoft's WinG layer for 256-colour graphics. A plain Wine
  # prefix does not ship the old WinG 1.x files, so seed the known-good copies
  # from the bundled Windows 3.x runtime; otherwise the game can stop at
  # "Your windows graphics driver can't display enough colors".
  mkdir -p "$PREFIX/drive_c/windows/system" "$PREFIX/drive_c/windows/system32"
  for wing_file in WING.DLL WING32.DLL WINGDE.DLL WINGDIB.DRV WINGPAL.WND; do
    if [[ -f "$GAME_TREE/WINDOWS/SYSTEM/$wing_file" ]]; then
      cp -f "$GAME_TREE/WINDOWS/SYSTEM/$wing_file" "$PREFIX/drive_c/windows/system/$wing_file"
      cp -f "$GAME_TREE/WINDOWS/SYSTEM/$wing_file" "$PREFIX/drive_c/windows/system32/$wing_file"
    fi
  done
}

if [[ "${GYS_WINE95_DRY_RUN:-0}" == "1" ]]; then
  resolve_wine
  printf 'HERE=%s\nREPO_ROOT=%s\nARCHIVE=%s\nRUNTIME_DIR=%s\nCDROM_ISO=%s\nCDROM_DIR=%s\nWINEPREFIX=%s\nWINEBIN=%s\nTARGET=%s\nDESKTOP=%s,%s\n' \
    "$HERE" "$REPO_ROOT" "$ARCHIVE" "$RUNTIME_DIR" "$CDROM_ISO" "$CDROM_DIR" "$PREFIX" "$WINEBIN" "$TARGET_EXE" "$DESKTOP_NAME" "$DESKTOP_SIZE"
  exit 0
fi

resolve_wine
extract_bundle_if_needed
prepare_cdrom
prepare_prefix

export WINEPREFIX="$PREFIX"
export WINEDEBUG="${GYS_WINEDEBUG:--all}"
export WINEDLLOVERRIDES="${GYS_WINEDLLOVERRIDES:-wing,wing32,wingde,wingdib=n,b}"
"$WINEBIN" start /exec explorer "/desktop=${DESKTOP_NAME},${DESKTOP_SIZE}" "$TARGET_EXE" "${TARGET_ARGS[@]}"
wineserver -w
