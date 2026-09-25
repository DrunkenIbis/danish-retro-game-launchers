#!/usr/bin/env bash
# PRIVATE local artifact: contains licensed game data/registration. Do not share.
set -Eeuo pipefail
umask 077
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$(cd "$HERE/.." && pwd)"
source "$GAME_DIR/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$GAME_DIR")"
PROJECT_NAME=battlefield-1942-secret-weapons
DISPLAY_NAME='Battlefield 1942 Secret Weapons of WWII 1.61b SiMPLE'
APPDIR="${APPDIR:-$ROOT/local/tmp/battlefield-1942-secret-weapons-appimage/Battlefield1942.AppDir}"
DIST_DIR="${DIST_DIR:-$ROOT/local/runtime/battlefield-1942/secret-weapons-appimage-dist}"
CACHE_DIR="${CACHE_DIR:-$ROOT/local/cache/battlefield-1942-secret-weapons-appimage}"
OUTPUT_APPIMAGE="$DIST_DIR/Battlefield-1942-Secret-Weapons-1.61b-SiMPLE-x86_64.AppImage"
SEED="${BF1942_BUILD_SEED:-$(retro_runtime_dir "$ROOT" battlefield-1942)/secret-weapons-simple161b/prefix-gameplay-verified}"
RUNNER="${BF1942_BUILD_RUNNER:-$ROOT/local/runners/lutris-GE-Proton7-43-x86_64}"
source "$ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults
wine_appimage_validate_base_tools
for tool in flock timeout wrestool; do wine_appimage_need "$tool"; done
for target in "$APPDIR/.private-probe" "$CACHE_DIR/.private-probe" "$OUTPUT_APPIMAGE"; do
 git -C "$ROOT" check-ignore -q "$target" || wine_appimage_fatal 'All build outputs must be git-ignored'
done
[[ "$APPDIR" == /* && "$APPDIR" != / && ! -L "$APPDIR" ]] || wine_appimage_fatal 'Invalid AppDir'
[[ ! -e "$OUTPUT_APPIMAGE" ]] || wine_appimage_fatal 'Existing artifact preserved; choose another DIST_DIR'
[[ -f "$SEED/system.reg" && -x "$RUNNER/bin/wine" && -x "$RUNNER/bin/wineserver" ]]
exec 9>"$(dirname "$SEED")/.launch.lock"
flock -n 9 || wine_appimage_fatal 'Source runtime locked'
WINEPREFIX="$SEED" timeout 5 "$RUNNER/bin/wineserver" -w 9>&- || wine_appimage_fatal 'Seed still running'
python3 - "$SEED" <<'PY'
from pathlib import Path
import hashlib,json,sys
p=Path(sys.argv[1]);g=p/'drive_c/Program Files/EA GAMES/Battlefield 1942'
assert (g/'Mods/XPack2/Archives/bf1942/Levels/Telemark.rfa').is_file(), 'Missing expansion assets'
assert not p.is_symlink() and not (p/'drive_c').is_symlink()
m=json.loads((p.parent/'logs/simple-patch-manifest.json').read_text())
for entry in m['changes']:
 f=g/entry['path']
 assert hashlib.sha256(f.read_bytes()).hexdigest()==entry['after'], 'Changed patch payload: '+entry['path']
PY
wine_appimage_reset_dirs
cp -a "$RUNNER" "$APPDIR/wine"
mkdir -p "$APPDIR/game/prefix"
cp -a --reflink=auto "$SEED/." "$APPDIR/game/prefix/"
python3 - "$APPDIR/game/prefix" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
for link in (p/'dosdevices').iterdir():
 if link.is_symlink():link.unlink()
(p/'dosdevices/c:').symlink_to('../drive_c')
(p/'dosdevices/z:').symlink_to('/')
for link in (p/'drive_c/users').rglob('*'):
 if link.is_symlink() and link.readlink().is_absolute():
  link.unlink();link.mkdir()
PY
cp "$HERE/AppRun.secret-weapons" "$APPDIR/AppRun"
printf '%s\n' '#!/usr/bin/env bash' 'exec "$(cd "$(dirname "$0")/../.." && pwd)/AppRun" "$@"' > "$APPDIR/usr/bin/$PROJECT_NAME"
chmod +x "$APPDIR/AppRun" "$APPDIR/usr/bin/$PROJECT_NAME"
wine_appimage_write_desktop_file
wrestool -x -t 14 -n 101 "$SEED/drive_c/Program Files/EA GAMES/Battlefield 1942/BF1942.exe" > "$CACHE_DIR/bf1942.ico"
wine_appimage_write_icon "$CACHE_DIR/bf1942.ico"
wine_appimage_verify_appdir
if [[ "$APPDIR_ONLY" != 1 ]]; then
 wine_appimage_build_appimage
 chmod 700 "$OUTPUT_APPIMAGE"
 sha256sum "$OUTPUT_APPIMAGE" > "$OUTPUT_APPIMAGE.sha256"
fi
wine_appimage_summarize
