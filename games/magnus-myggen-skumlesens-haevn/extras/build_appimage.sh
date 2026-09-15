#!/usr/bin/env bash
# Private local-copy package. Never run installation or modify source state.
set -Eeuo pipefail
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
GAME_DIR=$(cd "$SCRIPT_DIR/.." && pwd -P)
REPO=$(cd "$GAME_DIR/../.." && pwd -P)
PROJECT_NAME=magnus-myggen-skumlesens-haevn
DISPLAY_NAME='Magnus & Myggen: Skumlesens hævn'
RUNTIME="$(realpath -e -- "${MM3_APPIMAGE_RUNTIME:-$REPO/local/runtime/mm3-local-copy}")"
PREFIX="$RUNTIME/prefix-ge"
GE="$REPO/local/cache/mm3-physical-cd/runner/lutris-GE-Proton7-43-x86_64"
INSTALLED='drive_c/Program Files/IVANOFF Interactive/Skumlesens hævn'
source "$REPO/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults
wine_appimage_validate_base_tools
for tool in magick flock timeout sha256sum; do wine_appimage_need "$tool"; done
[[ ! -L $PREFIX && -s $PREFIX/system.reg && -s "$PREFIX/$INSTALLED/mm3run.exe" ]] || wine_appimage_fatal 'Original local-copy installation missing.'
[[ -d $RUNTIME/cdrom && ! -L $RUNTIME/cdrom ]] || wine_appimage_fatal 'Local CD tree missing.'
for dir in bin lib lib64 share; do [[ -d $GE/$dir ]] || wine_appimage_fatal "Incomplete GE runner: $dir"; done
[[ -x $GE/bin/wine && -x $GE/bin/wineserver ]] || wine_appimage_fatal 'GE executables missing.'
ICON="$RUNTIME/cdrom/mm.ico"
[[ -f $ICON ]] || ICON="$RUNTIME/cdrom/MM.ICO"
[[ -f $ICON ]] || wine_appimage_fatal 'Original mm.ico missing.'
# Hold the same lock as local_copy.sh through copying/building. Never kill it.
exec 9>"$RUNTIME/local-copy.lock"
flock -n 9 || wine_appimage_fatal 'Close the source local-copy game before building.'
env -u WINEDLLPATH WINEPREFIX="$PREFIX" WINEARCH=win32 WINESERVER="$GE/bin/wineserver" LD_LIBRARY_PATH="$GE/lib:$GE/lib64" timeout 3 "$GE/bin/wineserver" -w || wine_appimage_fatal 'Source Wine is still running; close it before building.'
APPIMAGETOOL_BIN="$REPO/local/cache/gys-paa-regneslottet/appimagetool-x86_64.AppImage"
[[ -x $APPIMAGETOOL_BIN ]] || wine_appimage_fatal 'Pinned Solur appimagetool missing.'
printf '%s  %s\n' b90f4a8b18967545fda78a445b27680a1642f1ef9488ced28b65398f2be7add2 "$APPIMAGETOOL_BIN" | sha256sum -c -
printf '%s  %s\n' 129e744fa1ed563771732ca99d245973cf2b4cf87213c532d2000f96a4078262 "$PREFIX/$INSTALLED/mm3run.exe" | sha256sum -c -
DOWNLOAD_APPIMAGETOOL=0
mkdir -p "$SCRIPT_DIR/build" "$SCRIPT_DIR/dist"
WORK=$(mktemp -d "$SCRIPT_DIR/build/mm3.XXXXXXXX")
# Keep disk-backed AppDir for inspection; each invocation uses its own tree.
APPDIR="$WORK/$PROJECT_NAME.AppDir"
CACHE_DIR="$WORK/cache"
DIST_DIR="$(realpath -m -- "${MM3_APPIMAGE_DIST:-$SCRIPT_DIR/dist}")"
OUTPUT_APPIMAGE="$DIST_DIR/$PROJECT_NAME-x86_64.AppImage"
wine_appimage_reset_dirs
cp -a "$PREFIX" "$APPDIR/game/prefix"
cp -a "$RUNTIME/cdrom" "$APPDIR/game/cdrom"
cp -a "$GE" "$APPDIR/usr/wine-ge"
# Only these stale mappings are removed from the disposable prefix copy.
for name in d: d:: e: e::; do
    path="$APPDIR/game/prefix/dosdevices/$name"
    [[ ! -e $path || -L $path ]] || wine_appimage_fatal "Unexpected non-symlink: $path"
    rm -f -- "$path"
done
chmod -R a-w "$APPDIR/game/cdrom"
install -m755 "$SCRIPT_DIR/AppRun" "$APPDIR/AppRun"
printf '#!/usr/bin/env bash\nexec "$(cd "$(dirname "$0")/../.." && pwd)/AppRun" "$@"\n' > "$APPDIR/usr/bin/$PROJECT_NAME"
chmod +x "$APPDIR/usr/bin/$PROJECT_NAME"
wine_appimage_write_desktop_file
magick "$ICON[0]" -resize 256x256 "$APPDIR/$PROJECT_NAME.png"
cp "$APPDIR/$PROJECT_NAME.png" "$APPDIR/.DirIcon"
cp "$APPDIR/$PROJECT_NAME.png" "$APPDIR/usr/share/icons/hicolor/256x256/apps/$PROJECT_NAME.png"
wine_appimage_verify_appdir
wine_appimage_build_appimage
(cd "$DIST_DIR" && sha256sum "$PROJECT_NAME-x86_64.AppImage" > "$PROJECT_NAME-x86_64.AppImage.sha256")
wine_appimage_summarize
