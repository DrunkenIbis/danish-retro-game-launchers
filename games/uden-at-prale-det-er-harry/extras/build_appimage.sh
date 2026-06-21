#!/usr/bin/env bash
set -Eeuo pipefail

# Build an AppDir/AppImage that bundles Uden at prale, det er Harry + Wine.
# This uses the generic Wine AppImage helper so other Wine recipes can reuse the
# same AppDir/AppImage mechanics and keep per-game scripts mostly declarative.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$GAME_DIR/../.." && pwd)"

PROJECT_NAME="uden-at-prale-det-er-harry"
DISPLAY_NAME="Uden at prale, det er Harry"
ARCH="${ARCH:-x86_64}"
APPDIR="${APPDIR:-$SCRIPT_DIR/build/${PROJECT_NAME}.AppDir}"
DIST_DIR="${DIST_DIR:-$SCRIPT_DIR/dist}"
CACHE_DIR="${CACHE_DIR:-$SCRIPT_DIR/.cache-appimage}"
OUTPUT_APPIMAGE="${OUTPUT_APPIMAGE:-$DIST_DIR/${PROJECT_NAME}-${ARCH}.AppImage}"
STATE_DIR_BASENAME="$PROJECT_NAME"
PREFIX_SEED_REL="game/wineprefix"
INTERNAL_LAUNCHER_REL="game/appimage-launch.sh"
IV32_BACKUP_SOURCE_DEFAULT="$REPO_ROOT/../lutris_game_scripts_uden_at_prale_harry/wineprefix_ge/drive_c/Harry/movies.original-iv32-backup"
IV32_BACKUP_SOURCE="${HARRY_IV32_BACKUP_SOURCE:-$IV32_BACKUP_SOURCE_DEFAULT}"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
RUNTIME_DIR="${HARRY_RUNTIME_DIR:-$RUNTIME_BASE/$PROJECT_NAME}"
ISO_PATH="${HARRY_ISO:-$SOURCE_BASE/$PROJECT_NAME/uden-at-prale-det-er-harry.iso}"
CDROM_DIR="${HARRY_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
PREFIX_DIR="${HARRY_WINEPREFIX:-$RUNTIME_DIR/wineprefix}"
ICON_SOURCE="${HARRY_ICON_SOURCE:-$CDROM_DIR/harry.ico}"

APPDIR_ONLY=0

source "$REPO_ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults

usage() {
  cat <<'EOF'
Brug:
  ./extras/build_appimage.sh [--appdir-only] [--no-download]

Bygger en selvstændig AppDir/AppImage for Uden at prale, det er Harry.
Kør normalt først:

  ./install.sh --download --no-launch
  HARRY_MODE=prepare ./launch.sh

Scriptet pakker:
  - extracted CD-ROM runtime
  - prepared Wine prefix with installed C:\Harry
  - host Wine runtime and ELF dependencies
  - AppImage launcher that copies the seed prefix to ~/.local/share on first run

Miljøvariable:
  HARRY_ISO=...             ISO der kan udtrækkes hvis runtime mangler
  HARRY_RUNTIME_DIR=...     runtime mappe med cdrom/ og wineprefix/
  HARRY_WINEPREFIX=...      prepared Wine prefix
  APPDIR=...                hvor AppDir bygges
  DIST_DIR=...              output mappe
  OUTPUT_APPIMAGE=...       endelig AppImage-sti
  APPIMAGETOOL_BIN=...      brug specifik appimagetool binær
  DOWNLOAD_APPIMAGETOOL=0   undgå auto-download

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

prepare_harry_runtime() {
  if [[ ! -f "$CDROM_DIR/CDmenu.exe" || ! -x "$PREFIX_DIR/drive_c/Harry/harry.exe" ]]; then
    [[ -f "$ISO_PATH" ]] || wine_appimage_fatal "Runtime mangler og ISO blev ikke fundet: $ISO_PATH. Kør ./install.sh --download --no-launch først."
  fi
  wine_appimage_log "Forbereder Harry runtime via launch.sh prepare"
  HARRY_ISO="$ISO_PATH" HARRY_RUNTIME_DIR="$RUNTIME_DIR" HARRY_WINEPREFIX="$PREFIX_DIR" HARRY_IV32_BACKUP_SOURCE="$IV32_BACKUP_SOURCE" \
    HARRY_MODE=prepare "$GAME_DIR/launch.sh"
}

copy_harry_game_files() {
  wine_appimage_log "Kopierer Harry runtime"
  install -Dm755 "$GAME_DIR/launch.sh" "$APPDIR/game/launch.sh"
  install -Dm644 "$GAME_DIR/README.md" "$APPDIR/game/README.md"
  install -Dm644 "$GAME_DIR/lutris.yml" "$APPDIR/game/lutris.yml"
  wine_appimage_sync_tree "$CDROM_DIR" "$APPDIR/game/cdrom"
  wine_appimage_sync_tree "$PREFIX_DIR" "$APPDIR/game/wineprefix"
  find "$APPDIR/game" -name '*.log' -delete || true
}

write_harry_internal_launcher() {
  wine_appimage_log "Skriver Harry AppImage launcher"
  cat > "$APPDIR/game/appimage-launch.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="${APPDIR:?APPDIR not set}"
APP_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/uden-at-prale-det-er-harry"
STATE_CDROM="$APP_STATE_DIR/cdrom"
CDROM_LOCK="$APP_STATE_DIR/.cdrom-copy.lock"
mkdir -p "$APP_STATE_DIR"
(
  flock 8
  if [[ -d "$HERE/game/wineprefix/drive_c/Harry/movies" ]]; then
    rm -rf "$WINEPREFIX/drive_c/Harry/movies"
    mkdir -p "$WINEPREFIX/drive_c/Harry/movies"
    cp -a "$HERE/game/wineprefix/drive_c/Harry/movies/." "$WINEPREFIX/drive_c/Harry/movies/"
  fi
  if [[ -d "$HERE/game/wineprefix/drive_c/Harry/movies.original-iv32-backup" ]]; then
    rm -rf "$WINEPREFIX/drive_c/Harry/movies.original-iv32-backup"
    mkdir -p "$WINEPREFIX/drive_c/Harry/movies.original-iv32-backup"
    cp -a "$HERE/game/wineprefix/drive_c/Harry/movies.original-iv32-backup/." "$WINEPREFIX/drive_c/Harry/movies.original-iv32-backup/"
  fi
  if [[ ! -f "$STATE_CDROM/CDmenu.exe" ]]; then
    rm -rf "$STATE_CDROM"
    mkdir -p "$STATE_CDROM"
    cp -a "$HERE/game/cdrom/." "$STATE_CDROM/"
  fi
) 8>"$CDROM_LOCK"
export HARRY_RUNTIME_DIR="$APP_STATE_DIR/runtime"
export HARRY_WINEPREFIX="$WINEPREFIX"
export HARRY_CDROM_DIR="$STATE_CDROM"
export HARRY_ISO="$HERE/game/uden-at-prale-det-er-harry.iso"
export HARRY_IV32_BACKUP_SOURCE="$HERE/game/wineprefix/drive_c/Harry/movies.original-iv32-backup"
export HARRY_WINE="${WINE_BIN:?WINE_BIN not set}"
export HARRY_WINESERVER="${WINE_BIN:?WINE_BIN not set}"
export HARRY_AUTO_INSTALL=0
export WINEDEBUG="${WINEDEBUG:--all}"
cd "$HERE/game"
exec "$HERE/game/launch.sh" "${1:-${HARRY_MODE:-game}}"
EOF
  chmod +x "$APPDIR/game/appimage-launch.sh"
}

validate_harry_inputs() {
  wine_appimage_validate_base_tools
  prepare_harry_runtime
  [[ -f "$CDROM_DIR/CDmenu.exe" ]] || wine_appimage_fatal "Mangler CDmenu.exe i $CDROM_DIR"
  [[ -f "$CDROM_DIR/setup.exe" ]] || wine_appimage_fatal "Mangler setup.exe i $CDROM_DIR"
  [[ -x "$PREFIX_DIR/drive_c/Harry/harry.exe" ]] || wine_appimage_fatal "Mangler installed harry.exe i $PREFIX_DIR"
  if command -v ffprobe >/dev/null 2>&1; then
    local movies_dir="$PREFIX_DIR/drive_c/Harry/movies"
    local movie codec_name dims checked_any=0 base
    [[ -d "$movies_dir" ]] || wine_appimage_fatal "Mangler movies-mappe i $movies_dir"
    shopt -s nullglob
    for movie in "$movies_dir"/*.avi; do
      checked_any=1
      base="$(basename "$movie")"
      codec_name="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$movie" 2>/dev/null || true)"
      [[ "$codec_name" == "msvideo1" ]] || wine_appimage_fatal "Movie codec er ikke Microsoft Video 1: $movie ($codec_name)"
      dims="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$movie" 2>/dev/null || true)"
      case "$base" in
        intro_scene_new_1.avi|cutscene_1.avi|cutscene_2.avi|cutscene_3.avi|outro.avi)
          [[ "$dims" == "400x216" ]] || wine_appimage_fatal "Movie dimension er ikke Director/MCI-kompatibel: $movie ($dims, forventede 400x216)"
          ;;
      esac
    done
    shopt -u nullglob
    [[ "$checked_any" == 1 ]] || wine_appimage_fatal "Ingen AVI-filer fundet i $movies_dir"
  fi
}

main() {
  validate_harry_inputs
  wine_appimage_reset_dirs
  copy_harry_game_files
  wine_appimage_copy_wine_runtime
  wine_appimage_collect_runtime_deps
  write_harry_internal_launcher
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
