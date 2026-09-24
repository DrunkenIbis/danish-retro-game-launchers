#!/usr/bin/env bash
# Original DOS CD installer; separate private C: drive, no Wine prefix.
set -euo pipefail
GAME_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$GAME_DIR/../../scripts/common.sh"
REPO=$(repo_root_from_game_dir "$GAME_DIR")
RUNTIME=${BUD_RUNTIME:-$(retro_runtime_dir "$REPO" bud-tucker-in-double-trouble)/physical}
CD=${BUD_CD:-/run/media/test/BUD_USA}
DEVICE=${BUD_DEVICE:-/dev/sr0}
MODE=${1:-setup}
[[ $MODE == setup || $MODE == check ]] || { printf 'Usage: %s [check|setup]\n' "$0" >&2; exit 2; }
python3 - "$CD" "$DEVICE" <<'PY'
import json, os, pathlib, stat, subprocess, sys
cd, device = sys.argv[1:]
r = subprocess.run(['findmnt','--json','--mountpoint',cd,'-o','SOURCE,TARGET,FSTYPE,OPTIONS'],capture_output=True,text=True,check=True)
f = json.loads(r.stdout)['filesystems'][0]
if os.path.realpath(f['source']) != os.path.realpath(device) or f['fstype'] != 'iso9660' or 'ro' not in f['options'].split(','):
    sys.exit('Expected the selected device mounted read-only as ISO9660.')
if not stat.S_ISBLK(os.stat(device).st_mode):
    sys.exit('Selected CD device is not a block device.')
label = subprocess.check_output(['lsblk','-dn','-o','LABEL',device],text=True).strip()
if label != 'BUD_USA':
    sys.exit('Wrong disc: expected BUD_USA, got '+label)
for name in ('install.bat','tucker/install.exe','tucker/setsound.exe','tucker/tucker.exe','tucker/dos4gw.exe'):
    if not (pathlib.Path(cd)/name).is_file():
        sys.exit('Missing original file: '+name)
for value in (cd,):
    if any(c in value for c in '\n\r"'):
        sys.exit('Unsupported path characters.')
print('Verified read-only BUD_USA:',device,'at',cd)
PY
[[ $MODE != check ]] || exit 0
flatpak info io.github.dosbox-staging >/dev/null
mkdir -p "$RUNTIME/c" "$RUNTIME/logs"
exec 9>"$RUNTIME/session.lock"
flock -n 9 || { printf 'This Bud Tucker installation is already running.\n' >&2; exit 1; }
python3 - "$GAME_DIR/dosbox.conf.in" "$RUNTIME" "$CD" <<'PY'
import pathlib, sys
template, runtime, cd = sys.argv[1:]
runtime = str(pathlib.Path(runtime).resolve())
if any(c in runtime for c in '\n\r"'):
    sys.exit('Unsupported runtime path characters.')
text = pathlib.Path(template).read_text().replace('@C_DRIVE@',runtime+'/c').replace('@CD@',cd)
pathlib.Path(runtime,'install.conf').write_text(text)
PY
# Per-invocation sandbox access, not a persistent Flatpak override.
flatpak run --filesystem="$CD:ro" --filesystem="$RUNTIME" --socket=x11 --nosocket=wayland --env=SDL_VIDEODRIVER=x11 \
  io.github.dosbox-staging --noprimaryconf --nolocalconf --conf "$RUNTIME/install.conf" \
  >"$RUNTIME/logs/install-$(date +%Y%m%d-%H%M%S).log" 2>&1
