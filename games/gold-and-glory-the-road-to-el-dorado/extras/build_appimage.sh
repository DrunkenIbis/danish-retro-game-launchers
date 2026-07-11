#!/usr/bin/env bash
set -Eeuo pipefail

# Build only from a locally owned copy of the game. Output is ignored by Git.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$GAME_DIR/../.." && pwd)"
PROJECT_NAME="gold-and-glory-the-road-to-el-dorado"
DISPLAY_NAME="Gold and Glory: The Road to El Dorado"
ARCH="${ARCH:-x86_64}"
APPDIR="${APPDIR:-$REPO_ROOT/local/appimage-build/$PROJECT_NAME/${PROJECT_NAME}.AppDir}"
DIST_DIR="${DIST_DIR:-$REPO_ROOT/local/appimage-dist/$PROJECT_NAME}"
CACHE_DIR="${CACHE_DIR:-$REPO_ROOT/local/appimage-cache/$PROJECT_NAME}"
OUTPUT_APPIMAGE="${OUTPUT_APPIMAGE:-$DIST_DIR/${PROJECT_NAME}-${ARCH}.AppImage}"
STATE_DIR_BASENAME="$PROJECT_NAME"
PREFIX_SEED_REL="game/wineprefix"
INTERNAL_LAUNCHER_REL="game/appimage-launch.sh"
SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${GGED_SOURCE_DIR:-$SOURCE_BASE/$PROJECT_NAME}"
RUNTIME_DIR="${GGED_RUNTIME_DIR:-$RUNTIME_BASE/$PROJECT_NAME}"
ISO_PATH="${GGED_ISO:-$SOURCE_DIR/ED_CD.iso}"
PREFIX_DIR="${GGED_WINEPREFIX:-$RUNTIME_DIR/wine-ge-prefix}"
WINE_GE_DIR="${GGED_WINE_GE_DIR:-$REPO_ROOT/local/runners/wine-ge-8-26}"
APPDIR_ONLY=0

source "$REPO_ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appdir-only) APPDIR_ONLY=1 ;;
    --no-download) DOWNLOAD_APPIMAGETOOL=0 ;;
    -h|--help)
      printf 'Usage: %s [--appdir-only] [--no-download]\n' "$0"
      exit 0 ;;
    *) wine_appimage_fatal "Ukendt argument: $1" ;;
  esac
  shift
done

validate_inputs() {
  wine_appimage_validate_base_tools
  [[ -f "$ISO_PATH" ]] || wine_appimage_fatal "Mangler ISO: $ISO_PATH"
  [[ -f "$PREFIX_DIR/system.reg" ]] || wine_appimage_fatal "Mangler Wine-GE seed prefix: $PREFIX_DIR"
  [[ -x "$WINE_GE_DIR/bin/wine" && -x "$WINE_GE_DIR/bin/wineserver" ]] || wine_appimage_fatal "Mangler Wine-GE runner: $WINE_GE_DIR"
}

copy_game_files() {
  install -Dm755 "$GAME_DIR/launch.sh" "$APPDIR/game/launch.sh"
  install -Dm755 "$GAME_DIR/center_window.py" "$APPDIR/game/center_window.py"
  install -Dm644 "$GAME_DIR/README.md" "$APPDIR/game/README.md"
  install -Dm644 "$GAME_DIR/recipe.yml" "$APPDIR/game/recipe.yml"
  install -Dm644 "$ISO_PATH" "$APPDIR/game/ED_CD.iso"
  wine_appimage_sync_tree "$PREFIX_DIR" "$APPDIR/game/wineprefix"
  rm -f "$APPDIR/game/wineprefix/dosdevices/d:" "$APPDIR/game/wineprefix/dosdevices/d::"
  wine_appimage_sync_tree "$WINE_GE_DIR" "$APPDIR/game/wine-ge"
  find "$APPDIR/game" -name '*.log' -delete || true
}

write_internal_launcher() {
  cat > "$APPDIR/game/appimage-launch.sh" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="${APPDIR:?APPDIR not set}"
APP_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/gold-and-glory-the-road-to-el-dorado"
mkdir -p "$APP_STATE_DIR"
STATE_ISO="$APP_STATE_DIR/ED_CD.iso"
if [[ ! -f "$STATE_ISO" || "$(stat -c '%s' "$STATE_ISO" 2>/dev/null || echo 0)" != "$(stat -c '%s' "$HERE/game/ED_CD.iso")" ]]; then
  cp -f "$HERE/game/ED_CD.iso" "$STATE_ISO.tmp"
  mv -f "$STATE_ISO.tmp" "$STATE_ISO"
fi
export GGED_RUNTIME_DIR="$APP_STATE_DIR/runtime"
export GGED_WINEPREFIX="$WINEPREFIX"
export GGED_ISO="$STATE_ISO"
export GGED_WINE_BIN="$HERE/game/wine-ge/bin/wine"
export GGED_WINE_GE=1
export GGED_VIRTUAL_DESKTOP="${GGED_VIRTUAL_DESKTOP:-1}"
export GGED_DESKTOP_SIZE="${GGED_DESKTOP_SIZE:-640x480}"
export GGED_CENTER_WINDOW="${GGED_CENTER_WINDOW:-1}"
export GGED_WINEDEBUG="${GGED_WINEDEBUG:--all}"
export GGED_LOCK_FILE="$APP_STATE_DIR/.launch.lock"
export LD_LIBRARY_PATH="$HERE/game/wine-ge/lib:$HERE/game/wine-ge/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd "$HERE/game"
exec "$HERE/game/launch.sh" "$@"
EOF
  chmod +x "$APPDIR/game/appimage-launch.sh"
}

main() {
  validate_inputs
  wine_appimage_reset_dirs
  copy_game_files
  wine_appimage_copy_wine_runtime
  wine_appimage_collect_runtime_deps
  write_internal_launcher
  wine_appimage_write_runner_scripts
  wine_appimage_write_desktop_file
  wine_appimage_write_icon ""
  wine_appimage_verify_appdir
  if [[ "$APPDIR_ONLY" == "0" ]]; then wine_appimage_build_appimage; fi
  wine_appimage_summarize
}
main "$@"
