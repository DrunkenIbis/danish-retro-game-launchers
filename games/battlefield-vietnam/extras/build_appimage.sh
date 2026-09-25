#!/usr/bin/env bash
# PRIVATE artifact: installed commercial game and registration. Do not distribute.
set -Eeuo pipefail
umask 077
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$GAME_DIR/../.." && pwd)"
MODE=fullscreen
case "${1:-}" in
  '') ;;
  --windowed) MODE=windowed; shift ;;
  *) printf '%s\n' 'Usage: build_appimage.sh [--windowed]' >&2; exit 1 ;;
esac
[[ $# == 0 ]] || { printf '%s\n' 'Unexpected build arguments.' >&2; exit 1; }
PROJECT_NAME=battlefield-vietnam
DISPLAY_NAME='Battlefield Vietnam'
BUILD_NAME=battlefield-vietnam-appimage
APPDIR_NAME=BattlefieldVietnam.AppDir
OUTPUT_NAME=Battlefield-Vietnam-1.21-SiMPLE-x86_64.AppImage
if [[ "$MODE" == windowed ]]; then
  PROJECT_NAME=battlefield-vietnam-windowed
  DISPLAY_NAME='Battlefield Vietnam (Windowed)'
  BUILD_NAME=battlefield-vietnam-windowed-appimage
  APPDIR_NAME=BattlefieldVietnamWindowed.AppDir
  OUTPUT_NAME=Battlefield-Vietnam-1.21-SiMPLE-Windowed-x86_64.AppImage
fi
APPDIR="${APPDIR:-$ROOT/local/tmp/$BUILD_NAME/$APPDIR_NAME}"
DIST_DIR="${DIST_DIR:-$ROOT/local/appimage-dist}"
CACHE_DIR="${CACHE_DIR:-$ROOT/local/cache/$BUILD_NAME}"
OUTPUT_APPIMAGE="$DIST_DIR/$OUTPUT_NAME"
SEED="$ROOT/local/runtime/battlefield-vietnam/simple121-ge7/prefix"
RUNNER="$ROOT/local/runners/lutris-GE-Proton7-43-x86_64"
source "$ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults
wine_appimage_validate_base_tools
wine_appimage_need flock
wine_appimage_need timeout
wine_appimage_need wrestool
# Check ignored output locations BEFORE copying private data or resetting dirs.
for target in "$APPDIR/.private-probe" "$CACHE_DIR/.private-probe" "$OUTPUT_APPIMAGE"; do
  git -C "$ROOT" check-ignore -q "$target" || wine_appimage_fatal 'All outputs must be git-ignored.'
done
[[ -f "$SEED/system.reg" && -x "$RUNNER/bin/wine" && -x "$RUNNER/bin/wineserver" ]]
exec 9>"$(dirname "$SEED")/.lock"
flock -n 9 || wine_appimage_fatal 'Source runtime is locked.'
WINEPREFIX="$SEED" timeout 5 "$RUNNER/bin/wineserver" -w 9>&- || wine_appimage_fatal 'Source prefix is running; stop it first.'
# Validate only; never print registry contents (contains a private CD key).
python3 - "$SEED" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
assert not p.is_symlink() and not (p/'drive_c').is_symlink()
assert '"INSTALLEDVERSION"="1.21.001"' in (p/'system.reg').read_text(errors='replace'), 'Expected version 1.21'
assert (p/'drive_c/Program Files/EA GAMES/Battlefield Vietnam/BfVietnam.exe').is_file()
PY
wine_appimage_reset_dirs
cp -a "$RUNNER" "$APPDIR/wine"
mkdir -p "$APPDIR/game/prefix"
cp -a --reflink=auto "$SEED/." "$APPDIR/game/prefix/"
# Bundle-local links only; no source-user home or physical/virtual CD links.
python3 - "$APPDIR/game/prefix" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
for link in (p/'dosdevices').iterdir():
    if link.is_symlink(): link.unlink()
(p/'dosdevices/c:').symlink_to('../drive_c')
(p/'dosdevices/z:').symlink_to('/')
# Wine's user-shell links must not refer back to the developer's home.
for link in (p/'drive_c/users').rglob('*'):
    if link.is_symlink() and link.readlink().is_absolute():
        link.unlink()
        link.mkdir()
PY
cp "$HERE/AppRun" "$APPDIR/AppRun"
cp "$HERE/normalize_windowed.py" "$APPDIR/normalize_windowed.py"
printf '%s\n' "$MODE" > "$APPDIR/launch-mode"
printf '%s\n' '#!/usr/bin/env bash' 'exec "$(cd "$(dirname "$0")/../.." && pwd)/AppRun" "$@"' > "$APPDIR/usr/bin/$PROJECT_NAME"
chmod +x "$APPDIR/AppRun" "$APPDIR/usr/bin/$PROJECT_NAME"
wine_appimage_write_desktop_file
# Extract the original game's icon, not the unrelated gamespy.ico.
wrestool -x -t 14 -n 101 "$SEED/drive_c/Program Files/EA GAMES/Battlefield Vietnam/BfVietnam.exe" > "$CACHE_DIR/bfvietnam.ico"
wine_appimage_write_icon "$CACHE_DIR/bfvietnam.ico"
wine_appimage_verify_appdir
if [[ "$APPDIR_ONLY" != 1 ]]; then
  wine_appimage_build_appimage
  chmod 700 "$OUTPUT_APPIMAGE"
fi
wine_appimage_summarize
