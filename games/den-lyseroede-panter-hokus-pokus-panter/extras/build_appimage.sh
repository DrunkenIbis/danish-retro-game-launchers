#!/usr/bin/env bash
set -Eeuo pipefail

# Build an AppDir/AppImage that bundles Den Lyserøde Panter: Hokus Pokus Panter + Wine.
# Build/distribute only if you have rights to the concrete game copy.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$GAME_DIR/../.." && pwd)"

PROJECT_NAME="den-lyseroede-panter-hokus-pokus-panter"
DISPLAY_NAME="Den Lyserøde Panter: Hokus Pokus Panter"
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
RUNTIME_DIR="${HPP_RUNTIME_DIR:-$RUNTIME_BASE/$PROJECT_NAME}"
ISO_PATH="${HPP_ISO:-$SOURCE_BASE/$PROJECT_NAME/Panter.iso}"
CDROM_DIR="${HPP_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
PREFIX_DIR="${HPP_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}"
ICON_SOURCE="${HPP_ICON_SOURCE:-$CDROM_DIR/INSTALL/HPP.ICO}"

APPDIR_ONLY=0

source "$REPO_ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults

usage() {
  cat <<'EOF'
Brug:
  ./extras/build_appimage.sh [--appdir-only] [--no-download]

Bygger en selvstændig AppDir/AppImage for Den Lyserøde Panter: Hokus Pokus Panter.
Kør normalt først:

  ./install.sh --download --no-launch
  HPP_MODE=prepare ./launch.sh

Scriptet pakker:
  - extracted CD-ROM runtime
  - seeded Wine prefix (without bundled game install); game files are installed to ~/.local/share on first run
  - host Wine runtime and ELF dependencies
  - AppImage launcher that stores mutable Wine prefix state in ~/.local/share

Miljøvariable:
  HPP_ISO=...             ISO der kan udtrækkes hvis runtime mangler
  HPP_RUNTIME_DIR=...     runtime mappe med cdrom/ og wineprefix32/
  HPP_WINEPREFIX=...      prepared Wine prefix
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

prepare_hpp_runtime() {
  if [[ -f "$CDROM_DIR/INSTALL/Hpp.exe" && -f "$PREFIX_DIR/drive_c/HokusPokusPanter/Hpp.exe" ]]; then
    return 0
  fi
  [[ -f "$ISO_PATH" ]] || wine_appimage_fatal "Runtime mangler og ISO blev ikke fundet: $ISO_PATH. Kør ./install.sh --download --no-launch først."
  wine_appimage_log "Forbereder Hokus Pokus Panter runtime via launch.sh prepare"
  HPP_ISO="$ISO_PATH" HPP_RUNTIME_DIR="$RUNTIME_DIR" HPP_WINEPREFIX="$PREFIX_DIR" \
    HPP_MODE=prepare "$GAME_DIR/launch.sh"
}

copy_hpp_game_files() {
  wine_appimage_log "Kopierer Hokus Pokus Panter runtime"
  install -Dm755 "$GAME_DIR/launch.sh" "$APPDIR/game/launch.sh"
  install -Dm644 "$GAME_DIR/README.md" "$APPDIR/game/README.md"
  install -Dm644 "$GAME_DIR/lutris.yml" "$APPDIR/game/lutris.yml"
  wine_appimage_sync_tree "$CDROM_DIR" "$APPDIR/game/cdrom"
  wine_appimage_sync_tree "$PREFIX_DIR" "$APPDIR/game/wineprefix"
  # Keep the seed prefix, but do not bundle the mutable installed game copy.
  # launch.sh recreates C:\HokusPokusPanter from the mounted CD-ROM on first run.
  rm -rf "$APPDIR/game/wineprefix/drive_c/HokusPokusPanter"
  find "$APPDIR/game" -name '*.log' -delete || true
}

write_hpp_internal_launcher() {
  wine_appimage_log "Skriver Hokus Pokus Panter AppImage launcher"
  cat > "$APPDIR/game/appimage-launch.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="${APPDIR:?APPDIR not set}"
APP_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/den-lyseroede-panter-hokus-pokus-panter"
mkdir -p "$APP_STATE_DIR"
# Keep the CD-ROM tree on the AppImage mount. It is read-only, but launch.sh only
# writes .windows-label opportunistically and tolerates failure. Avoid copying the
# 500+ MB CD tree out of the FUSE mount on every first run.
export HPP_RUNTIME_DIR="$APP_STATE_DIR/runtime"
export HPP_WINEPREFIX="$WINEPREFIX"
export HPP_CDROM_DIR="$HERE/game/cdrom"
export HPP_ISO="$HERE/game/Panter.iso"
export HPP_WINE_BIN="${WINE_BIN:?WINE_BIN not set}"
export HPP_MODE="${HPP_MODE:-game}"
export HPP_VIRTUAL_DESKTOP="${HPP_VIRTUAL_DESKTOP:-1}"
export HPP_DESKTOP_SIZE="${HPP_DESKTOP_SIZE:-640x480}"
export HPP_WINEDEBUG="${HPP_WINEDEBUG:--all}"
cd "$HERE/game"
exec "$HERE/game/launch.sh"
EOF
  chmod +x "$APPDIR/game/appimage-launch.sh"
}

validate_hpp_inputs() {
  wine_appimage_validate_base_tools
  prepare_hpp_runtime
  [[ -f "$CDROM_DIR/INSTALL/Hpp.exe" ]] || wine_appimage_fatal "Mangler INSTALL/Hpp.exe i $CDROM_DIR"
  [[ -f "$CDROM_DIR/hpp.orb" ]] || wine_appimage_fatal "Mangler hpp.orb i $CDROM_DIR"
}

main() {
  validate_hpp_inputs
  wine_appimage_reset_dirs
  copy_hpp_game_files
  wine_appimage_copy_wine_runtime
  wine_appimage_collect_runtime_deps
  write_hpp_internal_launcher
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
