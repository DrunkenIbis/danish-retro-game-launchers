#!/usr/bin/env bash
# Private local package, not for redistribution (contains original game/CD).
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$GAME_DIR/../.." && pwd)"
PROJECT_NAME=overboard
DISPLAY_NAME='Overboard!'
APPDIR="${APPDIR:-$ROOT/local/appimage-build/overboard/Overboard.AppDir}"
DIST_DIR="${DIST_DIR:-$ROOT/local/appimage-dist}"
CACHE_DIR="${CACHE_DIR:-$ROOT/local/appimage-cache/overboard}"
OUTPUT_APPIMAGE="$DIST_DIR/Overboard-x86_64.AppImage"
SEED="${OVERBOARD_BUILD_PREFIX:-$ROOT/local/runtime/overboard-image-test/wineprefix-ge}"
RUNNER="$ROOT/local/runners/lutris-GE-Proton7-43-x86_64"
MEDIA="${OVERBOARD_BUILD_MEDIA:-$ROOT/local/sources/overboard-original-cd}"
source "$ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults
wine_appimage_validate_base_tools
[[ -f "$SEED/system.reg" && -f "$MEDIA/OVERBOARD.toc" && -s "$MEDIA/OVERBOARD.bin" && -x "$RUNNER/bin/wine" ]]
[[ ! -e "$SEED/drive_c/Program Files/Psygnosis/Overboard!/ddraw.dll" ]] || wine_appimage_fatal 'Refusing experimental graphics-wrapper prefix'
WINEPREFIX="$SEED" timeout 5 "$RUNNER/bin/wineserver" -w
wine_appimage_reset_dirs
cp -a "$RUNNER" "$APPDIR/wine"
mkdir -p "$APPDIR/game/prefix"
cp -a "$SEED/." "$APPDIR/game/prefix/"
cp "$MEDIA/OVERBOARD.bin" "$MEDIA/OVERBOARD.toc" "$HERE/appimage_runtime.py" "$HERE/display_runner.py" "$APPDIR/game/"
XEPHYR_BIN="${XEPHYR_BIN:-$(command -v Xephyr || true)}"
XEPHYR_BIN="${XEPHYR_BIN:-$ROOT/local/runtime/overboard-intro-test/usr/bin/Xephyr}"
[[ -x "$XEPHYR_BIN" ]] || wine_appimage_fatal 'Installér Xephyr eller sæt XEPHYR_BIN'
cp "$XEPHYR_BIN" "$APPDIR/usr/bin/Xephyr"
# Pure Python dependencies are bundled; no uv/network needed at game launch.
uv run --with python-xlib==0.33 --with six==1.17.0 python - "$APPDIR/game/vendor" <<'PY'
import sys, shutil
from pathlib import Path
import Xlib, six
import importlib.metadata
out=Path(sys.argv[1]); out.mkdir()
shutil.copytree(Path(Xlib.__file__).parent,out/'Xlib')
shutil.copyfile(six.__file__,out/'six.py')
for name in ('python-xlib','six'):
    dist=importlib.metadata.distribution(name)
    for f in dist.files or []:
        if 'license' in str(f).lower() or 'copying' in str(f).lower():
            source=Path(dist.locate_file(f))
            if source.is_file(): shutil.copyfile(source,out/(name+'-'+source.name))
PY
python3 - "$APPDIR" "$HERE" <<'PY'
from pathlib import Path
import sys
app=Path(sys.argv[1])
sys.path.insert(0,sys.argv[2])
from appimage_runtime import relocate_toc
for p in (app/'game/prefix/dosdevices').iterdir():
    if p.is_symlink() and ':' in p.name and p.name != 'c:': p.unlink()
toc=app/'game/OVERBOARD.toc'
toc.write_text(relocate_toc(toc.read_text(),'OVERBOARD.bin'))
(app/'AppRun').write_text('#!/usr/bin/env bash\nset -e\nHERE="$(cd "$(dirname "$0")" && pwd)"\nexec python3 "$HERE/game/appimage_runtime.py" "$@"\n')
(app/'usr/bin/overboard').write_text('#!/usr/bin/env bash\nexec "$(cd "$(dirname "$0")/../.." && pwd)/AppRun" "$@"\n')
(app/'game/README.txt').write_text('Private Overboard CD backup. Requires host Python3, Gamescope, CDEmu/VHBA, udisksctl and compatible Wine/Xephyr system libraries. Wine-GE, Xephyr and Python-Xlib are bundled. Windowed 1024x768, 16-bit movie fix, aspect-preserving scaling. OVERBOARD_DISPLAY_MODE=classic selects the old Esc-to-skip path.\n')
PY
chmod +x "$APPDIR/AppRun" "$APPDIR/usr/bin/overboard"
wine_appimage_write_desktop_file
wine_appimage_write_icon "$SEED/drive_c/Program Files/Psygnosis/Overboard!/uninstal.ico"
wine_appimage_verify_appdir
if [[ "$APPDIR_ONLY" != 1 ]]; then wine_appimage_build_appimage; fi
wine_appimage_summarize
