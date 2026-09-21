#!/usr/bin/env bash
# Private original-Q112DK package; never publish bundled game/prefix/media.
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
GAME_DIR="$(cd "$HERE/.." && pwd)"
ROOT="$(cd "$GAME_DIR/../.." && pwd)"
PROJECT_NAME=quizkampen-q112dk
DISPLAY_NAME='Magnus & Myggen: Quizkampen (Q112DK)'
APPDIR="${APPDIR:-$ROOT/local/appimage-build/quizkampen-q112dk/Quizkampen-Q112DK.AppDir}"
DIST_DIR="${DIST_DIR:-$ROOT/local/appimage-dist}"
CACHE_DIR="${CACHE_DIR:-$ROOT/local/appimage-cache/quizkampen-q112dk}"
OUTPUT_APPIMAGE="$DIST_DIR/Quizkampen-Q112DK-WineGE-x86_64.AppImage"
SEED="$ROOT/local/runtime/magnus-myggen-quizkampen-superstarter/image-q112dk-ge/wineprefix32"
RUNNER="$ROOT/local/runners/lutris-GE-Proton7-43-x86_64"
ISO="$ROOT/local/sources/magnus-myggen-quizkampen-superstarter/Q112DK-original.iso"
# Reuse an existing local packager, never install/download packages implicitly.
APPIMAGETOOL_BIN="${APPIMAGETOOL_BIN:-$ROOT/local/appimage-cache/overboard/appimagetool-x86_64.AppImage}"
DOWNLOAD_APPIMAGETOOL=0
source "$ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults
wine_appimage_validate_base_tools
[[ $# == 0 ]] || wine_appimage_fatal 'Use APPDIR_ONLY=1 for AppDir-only mode; no positional arguments.'
[[ -f "$SEED/system.reg" && -f "$SEED/drive_c/Program Files/Magnus & Myggen - Quizkampen/mm12main.EXE" && -x "$RUNNER/bin/wine" && -x "$RUNNER/bin/wineserver" ]] || wine_appimage_fatal 'Gameplay-confirmed Q112DK prefix / full Wine-GE runner missing'
python3 - "$ISO" "$SEED" <<'PY'
from pathlib import Path
import hashlib, os, sys
iso, prefix = map(Path, sys.argv[1:])
assert iso.stat().st_size == 30296064, 'Wrong Q112DK image size'
assert hashlib.sha256(iso.read_bytes()).hexdigest() == 'b9e9b4f6edf703ad5be18638852c81e41a8dd964aca9191586ecdd8c549af1bd', 'Wrong Q112DK image digest'
for proc in Path('/proc').iterdir():
    if proc.name.isdigit():
        try:
            env = (proc/'environ').read_bytes().split(b'\0')
            assert os.fsencode('WINEPREFIX='+str(prefix)) not in env, 'Seed has a live process: '+proc.name
        except (FileNotFoundError, PermissionError, ProcessLookupError):
            pass
print('Q112DK image verified; no source-prefix processes found')
PY
WINEPREFIX="$SEED" timeout 5 "$RUNNER/bin/wineserver" -w
wine_appimage_reset_dirs
cp -a "$RUNNER" "$APPDIR/wine"
mkdir -p "$APPDIR/game/prefix"
cp -a "$SEED/." "$APPDIR/game/prefix/"
cp "$ISO" "$APPDIR/game/Q112DK.iso"
cp "$HERE/q112dk_runtime.py" "$APPDIR/game/q112dk_runtime.py"
cp "$GAME_DIR/Q112DK_APPIMAGE.md" "$APPDIR/game/README.md"
python3 - "$APPDIR" <<'PY'
from pathlib import Path
import sys
app=Path(sys.argv[1])
prefix=app/'game/prefix'
# Only change the copy. Remove machine-specific optical/serial/profile links.
for entry in (prefix/'dosdevices').iterdir():
    if entry.is_symlink() and entry.name != 'c:':
        entry.unlink()
for entry in (prefix/'drive_c/users').rglob('*'):
    if entry.is_symlink() and entry.readlink().is_absolute():
        entry.unlink()
        entry.mkdir()
(app/'AppRun').write_text('#!/usr/bin/env bash\nset -e\nHERE="$(cd "$(dirname "$0")" && pwd)"\nexec python3 "$HERE/game/q112dk_runtime.py" "$@"\n')
(app/'usr/bin/quizkampen-q112dk').write_text('#!/usr/bin/env bash\nexec "$(cd "$(dirname "$0")/../.." && pwd)/AppRun" "$@"\n')
PY
chmod +x "$APPDIR/AppRun" "$APPDIR/usr/bin/$PROJECT_NAME"
wine_appimage_write_desktop_file
wine_appimage_write_icon "$SEED/drive_c/Program Files/Magnus & Myggen - Quizkampen/mm.ico"
wine_appimage_verify_appdir
if [[ "$APPDIR_ONLY" != 1 ]]; then wine_appimage_build_appimage; fi
wine_appimage_summarize
