#!/usr/bin/env bash
# Private seed-based portable variant; does not replace the legacy CD AppImage.
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "$0")" && pwd)
GAME_DIR=$(cd "$HERE/.." && pwd)
ROOT=$(cd "$GAME_DIR/../.." && pwd)
PROJECT_NAME=overboard-portable
DISPLAY_NAME='Overboard! Portable'
APPDIR=${APPDIR:-$ROOT/local/appimage-build/overboard-portable/Overboard.AppDir}
DIST_DIR=${DIST_DIR:-$ROOT/local/appimage-dist}
CACHE_DIR=${CACHE_DIR:-$ROOT/local/appimage-cache/overboard-portable}
OUTPUT_APPIMAGE="$DIST_DIR/Overboard-KernelFree-Portable-x86_64.AppImage"
SEED=${OVERBOARD_BUILD_PREFIX:-$ROOT/local/runtime/overboard-kernel-free-probe/prefix}
RUNNER="$ROOT/local/runners/lutris-GE-Proton7-43-x86_64"
BF="$ROOT/games/battlefield-1942/extras"
source "$ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults
wine_appimage_validate_base_tools
[[ -f "$SEED/drive_c/Program Files/Psygnosis/Overboard!/winmm.ini" ]]
[[ ! -e "$SEED/drive_c/Program Files/Psygnosis/Overboard!/ddraw.dll" ]]
WINEPREFIX="$SEED" timeout 5 "$RUNNER/bin/wineserver" -w
[[ ! -e "$OUTPUT_APPIMAGE" ]] || wine_appimage_fatal 'Output already exists: choose a new DIST_DIR to preserve it'
wine_appimage_reset_dirs
cp -a "$RUNNER" "$APPDIR/wine"
mkdir -p "$APPDIR/game/prefix"
cp -a "$SEED/." "$APPDIR/game/prefix/"
PYTHONPATH="$HERE" python3 -c 'from portable_overboard import sanitize_prefix; import sys; sanitize_prefix(sys.argv[1])' "$APPDIR/game/prefix"
cp "$HERE/portable_overboard.py" "$HERE/display_runner.py" "$APPDIR/game/"
python3 "$BF/portable_runtime.py" build "$BF/portable-packages.json" "$ROOT/local/cache/battlefield-1942-portable" "$APPDIR/portable"
mkdir -p "$APPDIR/portable/bin"
for name in wine wine64 wineserver; do install -m755 "$BF/portable-wine" "$APPDIR/portable/bin/$name"; done
python3 "$HERE/bundle_display_runtime.py" "$APPDIR"
# Gamescope spawns gamescopereaper via PATH: it needs the private loader too.
for name in python3 Xephyr Xwayland xkbcomp gamescope gamescopereaper; do install -m755 "$HERE/portable-display" "$APPDIR/usr/bin/$name"; done
uv run --with python-xlib==0.33 --with six==1.17.0 python - "$APPDIR" <<'PY'
from pathlib import Path
import sys, shutil, json, hashlib
import Xlib, six
app=Path(sys.argv[1]); vendor=app/'game/vendor'; vendor.mkdir()
shutil.copytree(Path(Xlib.__file__).parent,vendor/'Xlib')
shutil.copyfile(six.__file__,vendor/'six.py')
egl=app/'display/share/glvnd/egl_vendor.d/50_mesa.json'
egl.parent.mkdir(parents=True,exist_ok=True)
egl.write_text(json.dumps({'file_format_version':'1.0.0','ICD':{'library_path':'libEGL_mesa.so.0'}}))
(app/'AppRun').write_text('#!/usr/bin/env bash\nset -e\nHERE="$(cd -- "$(dirname -- "$0")" && pwd)"\nexec "$HERE/usr/bin/python3" "$HERE/game/portable_overboard.py" "$@"\n')
(app/'usr/bin/overboard-portable').write_text('#!/usr/bin/env bash\nexec "$(cd -- "$(dirname -- "$0")/../.." && pwd)/AppRun" "$@"\n')
files={str(p.relative_to(app/'game/prefix')):hashlib.sha256(p.read_bytes()).hexdigest() for p in (app/'game/prefix/drive_c/Program Files/Psygnosis/Overboard!').glob('winmm.*') if p.suffix in ('.dll','.ini')}
(app/'game/seed-provenance.json').write_text(json.dumps(files,indent=2))
PY
chmod +x "$APPDIR/AppRun" "$APPDIR/usr/bin/overboard-portable"
cp "$HERE/display-experiments.md" "$APPDIR/game/"
wine_appimage_write_desktop_file
wine_appimage_write_icon "$SEED/drive_c/Program Files/Psygnosis/Overboard!/uninstal.ico"
wine_appimage_verify_appdir
"$APPDIR/AppRun" --check
if [[ "$APPDIR_ONLY" != 1 ]]; then wine_appimage_build_appimage; fi
wine_appimage_summarize
