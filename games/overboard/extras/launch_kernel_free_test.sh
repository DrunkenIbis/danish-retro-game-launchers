#!/usr/bin/env bash
# Host-only kernel-free probe, using the source display helper. Not an AppImage.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd -- "$here/../../.." && pwd)
state=${OVERBOARD_TEST_STATE:-$repo/local/runtime/overboard-kernel-free-probe}
wine=${OVERBOARD_WINE:-$repo/local/runners/lutris-GE-Proton7-43-x86_64/bin/wine}
xephyr=$(command -v Xephyr)
runtime=${XDG_RUNTIME_DIR:?XDG_RUNTIME_DIR is required}
display_number=${DISPLAY#:}
display_number=${display_number%%.*}
socket=/tmp/.X11-unix/X${display_number}
[[ -x "$wine" && -S "$socket" && -f "$state/prefix/drive_c/Program Files/Psygnosis/Overboard!/winmm.dll" ]] || {
  printf '%s\n' 'Missing test runtime, local X11 socket, or kernel-free WinMM.' >&2
  exit 1
}
# Private X11 directory avoids unmapped-root ownership errors under bwrap.
# Only the GPU is exposed: no optical devices or kernel CD emulator.
exec uv run --with python-xlib bwrap --ro-bind / / --dev /dev \
  --dev-bind /dev/dri /dev/dri --proc /proc --bind "$state" "$state" \
  --bind /tmp /tmp --tmpfs /tmp/.X11-unix --ro-bind "$socket" "$socket" \
  --bind "$runtime" "$runtime" --bind "${TMPDIR:?TMPDIR is required}" "$TMPDIR" \
  --setenv XDG_CACHE_HOME "$state/cache" \
  --setenv WINEPREFIX "$state/prefix" --setenv WINEDLLOVERRIDES 'winmm=n,b' \
  --setenv OVERBOARD_WINE "$wine" --setenv OVERBOARD_XEPHYR "$xephyr" \
  -- python "$here/display_runner.py" "$@"
