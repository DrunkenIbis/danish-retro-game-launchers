#!/usr/bin/env bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO="$(cd "$GAME_DIR/../.." && pwd)"
PROJECT_NAME=magnus-myggen-mysteriet-om-det-talende-solur
DISPLAY_NAME='Magnus & Myggen: Mysteriet om det talende solur'
RUNTIME="${SOLUR_RUNTIME_DIR:-${RETRO_GAME_RUNTIME_DIR:-$REPO/local/runtime}/$PROJECT_NAME}"
PREFIX="$RUNTIME/prefix"
INSTALLED='drive_c/Program Files/IVANOFF Interactive/Mysteriet om det talende solur'
[[ -s "$PREFIX/system.reg" && -s "$PREFIX/$INSTALLED/mm6.exe" ]] || { printf 'Kør original installation først.\n' >&2; exit 1; }
[[ -s "$RUNTIME/cdrom/SETUP.EXE" ]]
# Refuse a live prefix; copying it could lose pending registry/save writes.
WINEPREFIX="$PREFIX" timeout 3 wineserver -w || { printf 'Luk Solur før pakning.\n' >&2; exit 1; }
mkdir -p "$SCRIPT_DIR/build" "$SCRIPT_DIR/dist"
WORK="$(mktemp -d "$SCRIPT_DIR/build/solur.XXXXXXXX")"
trap 'rm -rf -- "$WORK"' EXIT
APPDIR="$WORK/$PROJECT_NAME.AppDir"
DIST_DIR="$SCRIPT_DIR/dist"
CACHE_DIR="$WORK/cache"
OUTPUT_APPIMAGE="$DIST_DIR/$PROJECT_NAME-x86_64.AppImage"
source "$REPO/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults
wine_appimage_validate_base_tools
# Reuse the locally cached, hash-pinned AppImageKit tool. It embeds its runtime.
APPIMAGETOOL_BIN="$REPO/local/cache/gys-paa-regneslottet/appimagetool-x86_64.AppImage"
[[ -x "$APPIMAGETOOL_BIN" ]] || { printf 'Pinned appimagetool is not executable: %s\n' "$APPIMAGETOOL_BIN" >&2; exit 1; }
python3 - "$APPIMAGETOOL_BIN" <<'PY'
import hashlib, sys
with open(sys.argv[1], 'rb') as f:
    if hashlib.file_digest(f, 'sha256').hexdigest() != 'b90f4a8b18967545fda78a445b27680a1642f1ef9488ced28b65398f2be7add2':
        sys.exit('appimagetool checksum mismatch')
PY
DOWNLOAD_APPIMAGETOOL=0
wine_appimage_reset_dirs
cp -a "$PREFIX" "$APPDIR/game/prefix"
cp -a "$RUNTIME/cdrom" "$APPDIR/game/cdrom"
# Strip only saves and the earlier CAB-only probe from the disposable COPY.
rm -rf "$APPDIR/game/prefix/$INSTALLED/sav" "$APPDIR/game/prefix/drive_c/MM6"
mkdir -p "$APPDIR/game/prefix/$INSTALLED/sav"
rm -f "$APPDIR/game/prefix/dosdevices/d:" "$APPDIR/game/prefix/dosdevices/d::"
wine_appimage_copy_wine_runtime
wine_appimage_collect_runtime_deps
install -m755 "$SCRIPT_DIR/AppRun" "$APPDIR/AppRun"
printf '#!/usr/bin/env bash\nexec "$(cd "$(dirname "$0")/../.." && pwd)/AppRun" "$@"\n' > "$APPDIR/usr/bin/$PROJECT_NAME"
chmod +x "$APPDIR/usr/bin/$PROJECT_NAME"
wine_appimage_write_desktop_file
# Convert only frame 0 to avoid multiple output files from the original ICO.
magick "$RUNTIME/cdrom/MM.ICO[0]" -resize 256x256 "$APPDIR/$PROJECT_NAME.png"
cp "$APPDIR/$PROJECT_NAME.png" "$APPDIR/.DirIcon"
cp "$APPDIR/$PROJECT_NAME.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$PROJECT_NAME.png"
cp "$GAME_DIR/README.md" "$APPDIR/README.md"
wine_appimage_verify_appdir
wine_appimage_build_appimage
(cd "$DIST_DIR" && sha256sum "$PROJECT_NAME-x86_64.AppImage" > "$PROJECT_NAME-x86_64.AppImage.sha256")
