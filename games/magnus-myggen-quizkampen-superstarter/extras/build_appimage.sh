#!/usr/bin/env bash
set -Eeuo pipefail

# Build an AppDir/AppImage that bundles Quizkampen Superstarter + Wine.
# The repository remains recipe-only; this script only packages the user's local,
# already prepared runtime under local/runtime/ into ignored extras/build/dist.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$GAME_DIR/../.." && pwd)"

PROJECT_NAME="magnus-myggen-quizkampen-superstarter"
DISPLAY_NAME="Magnus & Myggen: Quizkampen Superstarter"
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
RUNTIME_DIR="${MMQ_RUNTIME_DIR:-$RUNTIME_BASE/$PROJECT_NAME}"
ISO_PATH="${MMQ_ISO:-$SOURCE_BASE/$PROJECT_NAME/Quizkampen Superstarter Version.iso}"
CDROM_DIR="${MMQ_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
INSTALL_DIR="${MMQ_INSTALL_DIR:-$RUNTIME_DIR/installed}"
PREFIX_DIR="${MMQ_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}"
ICON_SOURCE="${MMQ_ICON_SOURCE:-$CDROM_DIR/MM.ICO}"

APPDIR_ONLY=0

source "$REPO_ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults

usage() {
  cat <<'EOF'
Brug:
  ./extras/build_appimage.sh [--appdir-only] [--no-download]

Bygger en selvstændig AppDir/AppImage for Magnus & Myggen: Quizkampen Superstarter.
Kør normalt først:

  ./install.sh --download --no-launch
  MMQ_MODE=prepare ./launch.sh

Miljøvariable:
  MMQ_ISO=...             ISO der kan udtrækkes hvis runtime mangler
  MMQ_RUNTIME_DIR=...     runtime mappe med cdrom/, installed/ og wineprefix32/
  MMQ_WINEPREFIX=...      prepared Wine prefix
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

prepare_quizkampen_runtime() {
  if [[ -f "$CDROM_DIR/DATA1.CAB" && -x "$INSTALL_DIR/mm12main.exe" && -f "$PREFIX_DIR/system.reg" ]]; then
    return 0
  fi
  [[ -f "$ISO_PATH" ]] || wine_appimage_fatal "Runtime mangler og ISO blev ikke fundet: $ISO_PATH. Kør ./install.sh --download --no-launch først."
  wine_appimage_log "Forbereder Quizkampen runtime via launch.sh prepare"
  MMQ_ISO="$ISO_PATH" MMQ_RUNTIME_DIR="$RUNTIME_DIR" MMQ_WINEPREFIX="$PREFIX_DIR" \
    MMQ_MODE=prepare "$GAME_DIR/launch.sh"
}

copy_quizkampen_game_files() {
  wine_appimage_log "Kopierer Quizkampen runtime"
  install -Dm755 "$GAME_DIR/launch.sh" "$APPDIR/game/launch.sh"
  install -Dm644 "$GAME_DIR/README.md" "$APPDIR/game/README.md"
  install -Dm644 "$GAME_DIR/lutris.yml" "$APPDIR/game/lutris.yml"
  wine_appimage_sync_tree "$CDROM_DIR" "$APPDIR/game/cdrom"
  wine_appimage_sync_tree "$INSTALL_DIR" "$APPDIR/game/installed"
  wine_appimage_sync_tree "$PREFIX_DIR" "$APPDIR/game/wineprefix"
  find "$APPDIR/game" -name '*.log' -delete || true
}

write_quizkampen_internal_launcher() {
  wine_appimage_log "Skriver Quizkampen AppImage launcher"
  cat > "$APPDIR/game/appimage-launch.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="${APPDIR:?APPDIR not set}"
APP_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/magnus-myggen-quizkampen-superstarter"
STATE_INSTALLED="$APP_STATE_DIR/installed"
STATE_PREFIX="$WINEPREFIX"
INSTALL_LOCK="$APP_STATE_DIR/.installed-copy.lock"
mkdir -p "$APP_STATE_DIR"
(
  flock 8
  if [[ ! -x "$STATE_INSTALLED/mm12main.exe" ]]; then
    rm -rf "$STATE_INSTALLED"
    mkdir -p "$STATE_INSTALLED"
    cp -a "$HERE/game/installed/." "$STATE_INSTALLED/"
  fi
) 8>"$INSTALL_LOCK"
export MMQ_RUNTIME_DIR="$APP_STATE_DIR/runtime"
export MMQ_WINEPREFIX="$STATE_PREFIX"
export MMQ_CDROM_DIR="$HERE/game/cdrom"
export MMQ_INSTALL_DIR="$STATE_INSTALLED"
export MMQ_ISO="$HERE/game/Quizkampen Superstarter Version.iso"
export MMQ_WINE_BIN="${WINE_BIN:?WINE_BIN not set}"
export MMQ_MODE="${MMQ_MODE:-game}"
export MMQ_FORCE_WIN32=0
export MMQ_WINEBOOT_TIMEOUT=10s
export WINEDEBUG="${WINEDEBUG:--all}"
cd "$HERE/game"
exec "$HERE/game/launch.sh" "$@"
EOF
  chmod +x "$APPDIR/game/appimage-launch.sh"
}

validate_quizkampen_inputs() {
  wine_appimage_validate_base_tools
  prepare_quizkampen_runtime
  [[ -f "$CDROM_DIR/DATA1.CAB" ]] || wine_appimage_fatal "Mangler DATA1.CAB i $CDROM_DIR"
  [[ -f "$CDROM_DIR/LAUNCHER.EXE" ]] || wine_appimage_fatal "Mangler LAUNCHER.EXE i $CDROM_DIR"
  [[ -x "$INSTALL_DIR/mm12main.exe" ]] || wine_appimage_fatal "Mangler installed mm12main.exe i $INSTALL_DIR"
  [[ -f "$INSTALL_DIR/standard.cxt" ]] || wine_appimage_fatal "Mangler standard.cxt i $INSTALL_DIR"
  [[ -f "$PREFIX_DIR/system.reg" ]] || wine_appimage_fatal "Mangler prepared Wine prefix i $PREFIX_DIR"
}

main() {
  validate_quizkampen_inputs
  wine_appimage_reset_dirs
  copy_quizkampen_game_files
  wine_appimage_copy_wine_runtime
  wine_appimage_collect_runtime_deps
  write_quizkampen_internal_launcher
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
