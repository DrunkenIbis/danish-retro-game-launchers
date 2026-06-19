#!/usr/bin/env bash
set -Eeuo pipefail

# Build an AppDir/AppImage that bundles Den Lyserøde Panter på hemmelig mission
# i udlandet / Pink Panther: Passport to Peril (DK) plus a prepared Wine runtime.
#
# Repository policy: the Git repo stays recipe-only. This script packages the
# user's local ISO-derived runtime into ignored extras/build and extras/dist output.
# Build/distribute only if you have rights to the concrete game copy.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$GAME_DIR/../.." && pwd)"

PROJECT_NAME="pink-panther-passport-to-peril"
DISPLAY_NAME="Den Lyserøde Panter: Passport to Peril"
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
SOURCE_DIR="${PP_SOURCE_DIR:-$SOURCE_BASE/$PROJECT_NAME}"
RUNTIME_DIR="${PP_RUNTIME_DIR:-$RUNTIME_BASE/$PROJECT_NAME}"
ISO_PATH="${PP_ISO:-$SOURCE_DIR/PANTER.iso}"
CDROM_DIR="${PP_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
PREFIX_DIR="${PP_WINEPREFIX:-$RUNTIME_DIR/wineprefix32}"
INSTALL_DIR="${PP_INSTALL_DIR:-$PREFIX_DIR/drive_c/Program Files/Pink Panther}"
ICON_SOURCE="${PP_ICON_SOURCE:-$INSTALL_DIR/PPTP.ICO}"

APPDIR_ONLY=0

source "$REPO_ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults

usage() {
  cat <<'EOF'
Brug:
  ./extras/build_appimage.sh [--appdir-only] [--no-download]

Bygger en selvstændig AppDir/AppImage for Den Lyserøde Panter på hemmelig
mission i udlandet / Pink Panther: Passport to Peril (DK).

Kør normalt først:

  ./install.sh --download --no-launch
  PP_MODE=prepare ./launch.sh

Scriptet kan også selv kalde launch.sh prepare, hvis PANTER.iso findes.
Det bruger samme generelle Wine-AppImage helper som de andre Wine-baserede
recipes i repoet.

Miljøvariable:
  PP_ISO=...             ISO der kan udtrækkes hvis runtime mangler
  PP_SOURCE_DIR=...      mappe med PANTER.iso
  PP_RUNTIME_DIR=...     runtime mappe med cdrom/ og wineprefix32/
  PP_CDROM_DIR=...       prepared/extracted CD-ROM directory
  PP_WINEPREFIX=...      prepared Wine prefix seed
  PP_INSTALL_DIR=...     prepared clean install under Wine prefix
  PP_ICON_SOURCE=...     ICO/PNG icon source, default clean install/PPTP.ICO
  APPDIR=...             hvor AppDir bygges
  DIST_DIR=...           output mappe
  OUTPUT_APPIMAGE=...    endelig AppImage-sti
  APPIMAGETOOL_BIN=...   brug specifik appimagetool binær
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

prepare_pp_runtime() {
  if [[ -f "$CDROM_DIR/INSTALL/PPTP.EXE" && -f "$CDROM_DIR/PPTP.ORB" \
        && -f "$INSTALL_DIR/PPTP.EXE" && -f "$INSTALL_DIR/.pink-panther-clean-install-v2" \
        && -f "$PREFIX_DIR/system.reg" ]]; then
    return 0
  fi

  [[ -f "$ISO_PATH" ]] || wine_appimage_fatal "Runtime mangler og ISO blev ikke fundet: $ISO_PATH. Kør ./install.sh --download --no-launch først, eller sæt PP_ISO=/sti/til/PANTER.iso."
  wine_appimage_log "Forbereder Pink Panther runtime via launch.sh prepare"
  PP_ISO="$ISO_PATH" \
    PP_SOURCE_DIR="$SOURCE_DIR" \
    PP_RUNTIME_DIR="$RUNTIME_DIR" \
    PP_CDROM_DIR="$CDROM_DIR" \
    PP_WINEPREFIX="$PREFIX_DIR" \
    PP_INSTALL_DIR="$INSTALL_DIR" \
    PP_MODE=prepare \
    "$GAME_DIR/launch.sh"
}

validate_pp_inputs() {
  wine_appimage_validate_base_tools
  prepare_pp_runtime
  [[ -f "$CDROM_DIR/AUTORUN.INF" ]] || wine_appimage_fatal "Mangler AUTORUN.INF i $CDROM_DIR"
  [[ -f "$CDROM_DIR/TEASER.EXE" ]] || wine_appimage_fatal "Mangler TEASER.EXE i $CDROM_DIR"
  [[ -f "$CDROM_DIR/INSTALL/PPTP.EXE" ]] || wine_appimage_fatal "Mangler INSTALL/PPTP.EXE i $CDROM_DIR"
  [[ -f "$CDROM_DIR/INSTALL/PPTP.BRO" ]] || wine_appimage_fatal "Mangler INSTALL/PPTP.BRO i $CDROM_DIR"
  [[ -f "$CDROM_DIR/ALLSONGS.PTP" ]] || wine_appimage_fatal "Mangler ALLSONGS.PTP i $CDROM_DIR"
  [[ -f "$CDROM_DIR/PPTP.ORB" ]] || wine_appimage_fatal "Mangler PPTP.ORB i $CDROM_DIR"
  [[ -f "$INSTALL_DIR/PPTP.EXE" ]] || wine_appimage_fatal "Mangler clean install PPTP.EXE i $INSTALL_DIR"
  [[ -f "$PREFIX_DIR/system.reg" ]] || wine_appimage_fatal "Mangler prepared Wine prefix i $PREFIX_DIR"
}

copy_pp_game_files() {
  wine_appimage_log "Kopierer Pink Panther runtime"
  install -Dm755 "$GAME_DIR/launch.sh" "$APPDIR/game/launch.sh"
  install -Dm644 "$GAME_DIR/README.md" "$APPDIR/game/README.md"
  install -Dm644 "$GAME_DIR/lutris.yml" "$APPDIR/game/lutris.yml"
  wine_appimage_sync_tree "$CDROM_DIR" "$APPDIR/game/cdrom"
  wine_appimage_sync_tree "$PREFIX_DIR" "$APPDIR/game/wineprefix"

  # Keep the seed prefix, but do not bundle the mutable clean-install copy twice.
  # launch.sh recreates C:\Program Files\Pink Panther inside the writable state
  # prefix from AppDir/game/cdrom on first run.
  rm -rf "$APPDIR/game/wineprefix/drive_c/Program Files/Pink Panther"
  rm -f "$APPDIR/game/wineprefix/dosdevices/d:" "$APPDIR/game/wineprefix/dosdevices/d::" || true
  find "$APPDIR/game" -name '*.log' -delete || true
}

write_pp_internal_launcher() {
  wine_appimage_log "Skriver Pink Panther AppImage launcher"
  cat > "$APPDIR/game/appimage-launch.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="${APPDIR:?APPDIR not set}"
APP_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/pink-panther-passport-to-peril"
mkdir -p "$APP_STATE_DIR"

# Keep the CD-ROM tree on the AppImage mount. It is read-only, but launch.sh only
# writes .windows-label opportunistically and tolerates failure. The mutable clean
# install is recreated in the writable Wine prefix under ~/.local/share.
export PP_RUNTIME_DIR="$APP_STATE_DIR/runtime"
export PP_WINEPREFIX="$WINEPREFIX"
export PP_CDROM_DIR="$HERE/game/cdrom"
export PP_ISO="$HERE/game/PANTER.iso"
export PP_WINE_BIN="${WINE_BIN:?WINE_BIN not set}"
export PP_MODE="${PP_MODE:-game}"
export PP_FORCE_WIN32=0
export PP_VIRTUAL_DESKTOP="${PP_VIRTUAL_DESKTOP:-1}"
export PP_DESKTOP_SIZE="${PP_DESKTOP_SIZE:-640x480}"
export PP_WINEDEBUG="${PP_WINEDEBUG:--all}"
cd "$HERE/game"
exec "$HERE/game/launch.sh" "$@"
EOF
  chmod +x "$APPDIR/game/appimage-launch.sh"
}

main() {
  validate_pp_inputs
  wine_appimage_reset_dirs
  copy_pp_game_files
  wine_appimage_copy_wine_runtime
  wine_appimage_collect_runtime_deps
  write_pp_internal_launcher
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
