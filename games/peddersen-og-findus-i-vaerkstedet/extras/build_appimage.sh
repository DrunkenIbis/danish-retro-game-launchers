#!/usr/bin/env bash
set -Eeuo pipefail

# Build an AppDir/AppImage that bundles Peddersen og Findus i værkstedet plus
# a prepared Wine runtime/prefix. The repository stays recipe-only; this script
# packages the user's local runtime under local/runtime/ into ignored extras/build
# and extras/dist output.
#
# Build/distribute only if you have rights to the concrete game copy.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$GAME_DIR/../.." && pwd)"

PROJECT_NAME="peddersen-og-findus-i-vaerkstedet"
DISPLAY_NAME="Peddersen og Findus i værkstedet"
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
SOURCE_DIR="${FINDUS1_SOURCE_DIR:-$SOURCE_BASE/$PROJECT_NAME}"
RUNTIME_DIR="${FINDUS1_RUNTIME_DIR:-$RUNTIME_BASE/$PROJECT_NAME}"
ISO_PATH="${FINDUS1_ISO:-$SOURCE_DIR/Peddersen-og-Findus-i-vaerkstedet.iso}"
CDROM_DIR="${FINDUS1_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
PREFIX_DIR="${FINDUS1_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}"
INSTALL_DIR="${FINDUS1_INSTALL_DIR:-$PREFIX_DIR/drive_c/Program Files/Findus1}"
ICON_SOURCE="${FINDUS1_ICON_SOURCE:-$CDROM_DIR/DATA/Findus1.ico}"

APPDIR_ONLY=0

source "$REPO_ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults

usage() {
  cat <<'EOF'
Brug:
  ./extras/build_appimage.sh [--appdir-only] [--no-download]

Bygger en selvstændig AppDir/AppImage for Peddersen og Findus i værkstedet.
Kør normalt først:

  ./install.sh --download --no-launch
  FINDUS1_MODE=prepare ./launch.sh

Scriptet kan også selv kalde launch.sh prepare, hvis ISO'en findes.
Det bruger samme generelle Wine-AppImage helper som de andre Wine-baserede
recipes i repoet.

Miljøvariable:
  FINDUS1_ISO=...          ISO der kan udtrækkes hvis runtime mangler
  FINDUS1_SOURCE_DIR=...   mappe med ISO'en
  FINDUS1_RUNTIME_DIR=...  runtime mappe med cdrom/ og wineprefix32/
  FINDUS1_CDROM_DIR=...    prepared/extracted CD-ROM directory
  FINDUS1_WINEPREFIX=...   prepared Wine prefix seed
  FINDUS1_INSTALL_DIR=...  prepared manual install under Wine prefix
  FINDUS1_ICON_SOURCE=...  ICO/PNG icon source, default cdrom/DATA/Findus1.ico
  APPDIR=...               hvor AppDir bygges
  DIST_DIR=...             output mappe
  OUTPUT_APPIMAGE=...      endelig AppImage-sti
  APPIMAGETOOL_BIN=...     brug specifik appimagetool binær
  DOWNLOAD_APPIMAGETOOL=0  undgå auto-download

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

prepare_findus_runtime() {
  if [[ -f "$CDROM_DIR/DATA/Findus1.exe" && -f "$CDROM_DIR/Media/start.dxr" \
        && -f "$INSTALL_DIR/Findus1.exe" && -f "$INSTALL_DIR/.findus1-manual-install-v1" \
        && -f "$PREFIX_DIR/system.reg" ]]; then
    return 0
  fi

  [[ -f "$ISO_PATH" ]] || wine_appimage_fatal "Runtime mangler og ISO blev ikke fundet: $ISO_PATH. Kør ./install.sh --download --no-launch først, eller sæt FINDUS1_ISO=/sti/til/ISO."
  wine_appimage_log "Forbereder Findus runtime via launch.sh prepare"
  FINDUS1_ISO="$ISO_PATH" \
    FINDUS1_SOURCE_DIR="$SOURCE_DIR" \
    FINDUS1_RUNTIME_DIR="$RUNTIME_DIR" \
    FINDUS1_CDROM_DIR="$CDROM_DIR" \
    FINDUS1_WINEPREFIX="$PREFIX_DIR" \
    FINDUS1_INSTALL_DIR="$INSTALL_DIR" \
    FINDUS1_MODE=prepare \
    "$GAME_DIR/launch.sh"
}

validate_findus_inputs() {
  wine_appimage_validate_base_tools
  prepare_findus_runtime
  [[ -f "$CDROM_DIR/autorun.inf" ]] || wine_appimage_fatal "Mangler autorun.inf i $CDROM_DIR"
  [[ -f "$CDROM_DIR/Installér Findus1.exe" ]] || wine_appimage_fatal "Mangler Installér Findus1.exe i $CDROM_DIR"
  [[ -f "$CDROM_DIR/DATA/Findus1.exe" ]] || wine_appimage_fatal "Mangler DATA/Findus1.exe i $CDROM_DIR"
  [[ -f "$CDROM_DIR/DATA/Indstillinger.exe" ]] || wine_appimage_fatal "Mangler DATA/Indstillinger.exe i $CDROM_DIR"
  [[ -f "$CDROM_DIR/DATA/Xtras/DirectOS.x32" ]] || wine_appimage_fatal "Mangler DATA/Xtras/DirectOS.x32 i $CDROM_DIR"
  [[ -f "$CDROM_DIR/DATA/Xtras/DirectSound.x32" ]] || wine_appimage_fatal "Mangler DATA/Xtras/DirectSound.x32 i $CDROM_DIR"
  [[ -f "$CDROM_DIR/Media/start.dxr" ]] || wine_appimage_fatal "Mangler Media/start.dxr i $CDROM_DIR"
  [[ -f "$CDROM_DIR/Media/Cast/shared.cxt" ]] || wine_appimage_fatal "Mangler Media/Cast/shared.cxt i $CDROM_DIR"
  [[ -f "$INSTALL_DIR/Findus1.exe" ]] || wine_appimage_fatal "Mangler manual install Findus1.exe i $INSTALL_DIR"
  [[ -f "$PREFIX_DIR/system.reg" ]] || wine_appimage_fatal "Mangler prepared Wine prefix i $PREFIX_DIR"
}

copy_findus_game_files() {
  wine_appimage_log "Kopierer Findus runtime"
  install -Dm755 "$GAME_DIR/launch.sh" "$APPDIR/game/launch.sh"
  install -Dm644 "$GAME_DIR/README.md" "$APPDIR/game/README.md"
  install -Dm644 "$GAME_DIR/lutris.yml" "$APPDIR/game/lutris.yml"
  wine_appimage_sync_tree "$CDROM_DIR" "$APPDIR/game/cdrom"
  wine_appimage_sync_tree "$PREFIX_DIR" "$APPDIR/game/wineprefix"

  # Keep the seeded prefix, but do not bundle the mutable manual-installed game
  # copy twice. launch.sh recreates C:\Program Files\Findus1 in the writable
  # state prefix from AppDir/game/cdrom on first run.
  rm -rf "$APPDIR/game/wineprefix/drive_c/Program Files/Findus1"
  rm -f "$APPDIR/game/wineprefix/dosdevices/d:" "$APPDIR/game/wineprefix/dosdevices/d::" || true
  find "$APPDIR/game" -name '*.log' -delete || true
}

write_findus_internal_launcher() {
  wine_appimage_log "Skriver Findus AppImage launcher"
  cat > "$APPDIR/game/appimage-launch.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="${APPDIR:?APPDIR not set}"
APP_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/peddersen-og-findus-i-vaerkstedet"
mkdir -p "$APP_STATE_DIR"

# Keep the CD-ROM tree on the AppImage mount. It is read-only, but launch.sh only
# writes .windows-label opportunistically and tolerates failure. The mutable
# manual install is recreated in the writable Wine prefix under ~/.local/share.
export FINDUS1_RUNTIME_DIR="$APP_STATE_DIR/runtime"
export FINDUS1_WINEPREFIX="$WINEPREFIX"
export FINDUS1_CDROM_DIR="$HERE/game/cdrom"
export FINDUS1_ISO="$HERE/game/Peddersen-og-Findus-i-vaerkstedet.iso"
export FINDUS1_WINE_BIN="${WINE_BIN:?WINE_BIN not set}"
export FINDUS1_MODE="${FINDUS1_MODE:-game}"
export FINDUS1_FORCE_WIN32=0
export FINDUS1_VIRTUAL_DESKTOP="${FINDUS1_VIRTUAL_DESKTOP:-1}"
export FINDUS1_DESKTOP_SIZE="${FINDUS1_DESKTOP_SIZE:-800x600}"
export FINDUS1_WINEDEBUG="${FINDUS1_WINEDEBUG:--all}"
export FINDUS1_LOCK_FILE="$APP_STATE_DIR/.findus1-launch.lock"
cd "$HERE/game"
exec "$HERE/game/launch.sh" "$@"
EOF
  chmod +x "$APPDIR/game/appimage-launch.sh"
}

main() {
  validate_findus_inputs
  wine_appimage_reset_dirs
  copy_findus_game_files
  wine_appimage_copy_wine_runtime
  wine_appimage_collect_runtime_deps
  write_findus_internal_launcher
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
