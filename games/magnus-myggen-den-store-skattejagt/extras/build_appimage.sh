#!/usr/bin/env bash
set -Eeuo pipefail

# Build an AppDir/AppImage that bundles Magnus & Myggen: Den Store Skattejagt
# plus a prepared Wine runtime/prefix. The repository stays recipe-only; this
# script packages the user's local runtime under local/runtime/ into ignored
# extras/build and extras/dist output.
#
# NOTE: AppImage reduces host dependencies, but cannot guarantee every Linux
# distribution/kernel/graphics/audio stack. Build/distribute only copies you have
# the right to package.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$GAME_DIR/../.." && pwd)"

PROJECT_NAME="magnus-myggen-den-store-skattejagt"
DISPLAY_NAME="Magnus & Myggen: Den Store Skattejagt"
ARCH="${ARCH:-x86_64}"
APPDIR="${APPDIR:-$SCRIPT_DIR/build/${PROJECT_NAME}.AppDir}"
DIST_DIR="${DIST_DIR:-$SCRIPT_DIR/dist}"
CACHE_DIR="${CACHE_DIR:-$SCRIPT_DIR/.cache-appimage}"
OUTPUT_APPIMAGE="${OUTPUT_APPIMAGE:-$DIST_DIR/${PROJECT_NAME}-${ARCH}.AppImage}"
STATE_DIR_BASENAME="$PROJECT_NAME"
PREFIX_SEED_REL="game/wineprefix"
INTERNAL_LAUNCHER_REL="game/appimage-launch.sh"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
RUNTIME_DIR="${MM2_RUNTIME_DIR:-$RUNTIME_BASE/$PROJECT_NAME}"
ISO_PATH="${MM2_ISO:-${MM2_ISO_PATH:-$SOURCE_BASE/$PROJECT_NAME/MM2NORD.iso}}"
CDROM_DIR="${MM2_CD_DIR:-$RUNTIME_DIR/cdrom}"
INSTALL_DIR="${MM2_INSTALL_DIR:-$RUNTIME_DIR/installed-dk}"
PREFIX_DIR="${MM2_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}"
ICON_SOURCE="${MM2_ICON_SOURCE:-$INSTALL_DIR/ii.ico}"

APPDIR_ONLY=0

source "$REPO_ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults

usage() {
  cat <<'EOF'
Brug:
  ./extras/build_appimage.sh [--appdir-only] [--no-download]

Bygger en selvstændig AppDir/AppImage for Magnus & Myggen: Den Store Skattejagt.
Kør normalt først:

  ./install.sh --download --no-launch
  MM2_MODE=prepare ./launch.sh

Scriptet kan også selv kalde launch.sh prepare, hvis ISO/runtime findes.

Miljøvariable:
  MM2_ISO=...             ISO der kan udtrækkes hvis runtime mangler
  MM2_RUNTIME_DIR=...     runtime mappe med cdrom/, installed-dk/ og wineprefix32/
  MM2_CD_DIR=...          prepared/extracted CD-ROM directory
  MM2_INSTALL_DIR=...     prepared installed game directory
  MM2_WINEPREFIX=...      prepared Wine prefix seed
  MM2_ICON_SOURCE=...     ICO/PNG icon source, default installed-dk/ii.ico
  APPDIR=...              hvor AppDir bygges
  DIST_DIR=...            output mappe
  OUTPUT_APPIMAGE=...     endelig AppImage-sti
  APPIMAGETOOL_BIN=...    brug specifik appimagetool binær
  DOWNLOAD_APPIMAGETOOL=0 undgå auto-download

Bemærk:
  AppImage-filen kommer til at indeholde spilfiler og et prepared Wine prefix.
  Byg/distribuér den kun hvis du har rettigheder til den konkrete kopi.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appdir-only) APPDIR_ONLY=1 ;;
    --no-download) DOWNLOAD_APPIMAGETOOL=0 ;;
    -h|--help) usage; exit 0 ;;
    *) wine_appimage_fatal "Ukendt argument: $1" ;;
  esac
  shift
done

prepare_mm2_runtime() {
  if [[ -f "$CDROM_DIR/MM2.DAT" && -f "$CDROM_DIR/DK/MM2LNG.DAT" \
        && -x "$INSTALL_DIR/MM2RUN.EXE" && -f "$INSTALL_DIR/default.pal" \
        && -f "$INSTALL_DIR/isrt.dll" && -f "$PREFIX_DIR/system.reg" ]]; then
    return 0
  fi

  [[ -f "$ISO_PATH" ]] || wine_appimage_fatal "Runtime mangler og ISO blev ikke fundet: $ISO_PATH. Kør ./install.sh --download --no-launch først, eller sæt MM2_ISO=/sti/til/MM2NORD.iso."
  wine_appimage_log "Forbereder MM2 runtime via launch.sh prepare"
  MM2_ISO="$ISO_PATH" \
    MM2_RUNTIME_DIR="$RUNTIME_DIR" \
    MM2_CD_DIR="$CDROM_DIR" \
    MM2_INSTALL_DIR="$INSTALL_DIR" \
    MM2_WINEPREFIX="$PREFIX_DIR" \
    MM2_MODE=prepare \
    "$GAME_DIR/launch.sh"
}

validate_mm2_inputs() {
  wine_appimage_validate_base_tools
  prepare_mm2_runtime
  [[ -f "$CDROM_DIR/DATA1.CAB" ]] || wine_appimage_fatal "Mangler DATA1.CAB i $CDROM_DIR"
  [[ -f "$CDROM_DIR/MM2.DAT" ]] || wine_appimage_fatal "Mangler MM2.DAT i $CDROM_DIR"
  [[ -f "$CDROM_DIR/MM2.IDX" ]] || wine_appimage_fatal "Mangler MM2.IDX i $CDROM_DIR"
  [[ -f "$CDROM_DIR/DK/MM2LNG.DAT" ]] || wine_appimage_fatal "Mangler DK/MM2LNG.DAT i $CDROM_DIR"
  [[ -f "$CDROM_DIR/DK/MM2LNG.IDX" ]] || wine_appimage_fatal "Mangler DK/MM2LNG.IDX i $CDROM_DIR"
  [[ -x "$INSTALL_DIR/MM2RUN.EXE" ]] || wine_appimage_fatal "Mangler installed MM2RUN.EXE i $INSTALL_DIR"
  [[ -f "$INSTALL_DIR/default.pal" ]] || wine_appimage_fatal "Mangler default.pal i $INSTALL_DIR"
  [[ -f "$INSTALL_DIR/isrt.dll" ]] || wine_appimage_fatal "Mangler isrt.dll i $INSTALL_DIR"
  [[ -f "$PREFIX_DIR/system.reg" ]] || wine_appimage_fatal "Mangler prepared Wine prefix i $PREFIX_DIR"
}

copy_mm2_game_files() {
  wine_appimage_log "Kopierer Den Store Skattejagt runtime"
  install -Dm755 "$GAME_DIR/launch.sh" "$APPDIR/game/launch.sh"
  install -Dm644 "$GAME_DIR/README.md" "$APPDIR/game/README.md"
  install -Dm644 "$GAME_DIR/lutris.yml" "$APPDIR/game/lutris.yml"
  wine_appimage_sync_tree "$CDROM_DIR" "$APPDIR/game/cdrom-template"
  wine_appimage_sync_tree "$INSTALL_DIR" "$APPDIR/game/installed-template"
  wine_appimage_sync_tree "$PREFIX_DIR" "$APPDIR/game/wineprefix"
  find "$APPDIR/game" -name '*.log' -delete || true
  rm -f "$APPDIR/game/wineprefix/dosdevices/d:" "$APPDIR/game/wineprefix/dosdevices/d::" || true
}

write_mm2_internal_launcher() {
  wine_appimage_log "Skriver Den Store Skattejagt AppImage launcher"
  cat > "$APPDIR/game/appimage-launch.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="${APPDIR:?APPDIR not set}"
APP_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/magnus-myggen-den-store-skattejagt"
STATE_CDROM="$APP_STATE_DIR/cdrom"
STATE_INSTALLED="$APP_STATE_DIR/installed-dk"
STATE_PREFIX="$WINEPREFIX"
COPY_LOCK="$APP_STATE_DIR/.runtime-copy.lock"
mkdir -p "$APP_STATE_DIR"

# The AppImage mount is read-only. Keep the Wine prefix and the CD-ROM tree in
# writable state because launch.sh writes .windows-label and rewrites dosdevices.
(
  flock 8
  if [[ ! -f "$STATE_CDROM/MM2.DAT" || ! -f "$STATE_CDROM/DK/MM2LNG.DAT" ]]; then
    rm -rf "$STATE_CDROM"
    mkdir -p "$STATE_CDROM"
    cp -a "$HERE/game/cdrom-template/." "$STATE_CDROM/"
  fi
  if [[ ! -x "$STATE_INSTALLED/MM2RUN.EXE" || ! -f "$STATE_INSTALLED/default.pal" || ! -f "$STATE_INSTALLED/isrt.dll" ]]; then
    rm -rf "$STATE_INSTALLED"
    mkdir -p "$STATE_INSTALLED"
    cp -a "$HERE/game/installed-template/." "$STATE_INSTALLED/"
  fi
) 8>"$COPY_LOCK"

export MM2_RUNTIME_DIR="$APP_STATE_DIR/runtime"
export MM2_CD_DIR="$STATE_CDROM"
export MM2_INSTALL_DIR="$STATE_INSTALLED"
export MM2_WINEPREFIX="$STATE_PREFIX"
export WINEPREFIX="$STATE_PREFIX"
export MM2_ISO="$HERE/game/MM2NORD.iso"
export MM2_WINE_BIN="${WINE_BIN:?WINE_BIN not set}"
export MM2_MODE="${MM2_MODE:-game}"
export MM2_FORCE_WIN32=0
export MM2_WINEBOOT_TIMEOUT="${MM2_WINEBOOT_TIMEOUT:-10s}"
export MM2_VIRTUAL_DESKTOP="${MM2_VIRTUAL_DESKTOP:-1}"
export MM2_CENTER_WINDOW="${MM2_CENTER_WINDOW:-1}"
export MM2_DESKTOP_SIZE="${MM2_DESKTOP_SIZE:-800x600}"
export MM2_WINVER="${MM2_WINVER:-win98}"
export MM2_LOCK_FILE="$APP_STATE_DIR/.mm2-launch.lock"
export WINEDEBUG="${WINEDEBUG:--all}"
cd "$HERE/game"
exec "$HERE/game/launch.sh" "$@"
EOF
  chmod +x "$APPDIR/game/appimage-launch.sh"
}

main() {
  validate_mm2_inputs
  wine_appimage_reset_dirs
  copy_mm2_game_files
  wine_appimage_copy_wine_runtime
  wine_appimage_collect_runtime_deps
  write_mm2_internal_launcher
  wine_appimage_write_runner_scripts
  wine_appimage_write_desktop_file
  wine_appimage_write_icon "$ICON_SOURCE"
  wine_appimage_verify_appdir
  if [[ "$APPDIR_ONLY" == "0" ]]; then
    wine_appimage_build_appimage
  fi
  wine_appimage_summarize
}

main "$@"
