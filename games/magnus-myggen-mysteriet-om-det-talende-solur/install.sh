#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(cd "$HERE/../.." && pwd)"
ID=magnus-myggen-mysteriet-om-det-talende-solur
SOURCE="${SOLUR_SOURCE_DIR:-${RETRO_GAME_SOURCE_DIR:-$REPO/local/sources}/$ID}"
RUNTIME="${SOLUR_RUNTIME_DIR:-${RETRO_GAME_RUNTIME_DIR:-$REPO/local/runtime}/$ID}"
DOWNLOAD=0
LAUNCH=1
for arg in "$@"; do
    case "$arg" in
        --download) DOWNLOAD=1 ;;
        --existing) DOWNLOAD=0 ;;
        --no-launch) LAUNCH=0 ;;
        *) printf 'Brug: %s [--download|--existing] [--no-launch]\n' "$0"; exit 1 ;;
    esac
done
mkdir -p "$SOURCE" "$RUNTIME/logs"
if [[ "$DOWNLOAD" == 1 ]]; then
    for name in M630DA.bin M630DA.cue; do
        curl -fL --retry 2 -C - -o "$SOURCE/$name.part" "https://archive.org/download/magnus-myggen-mysteriet-om-det-talende-solur/$name"
        mv "$SOURCE/$name.part" "$SOURCE/$name"
    done
fi
python3 - "$SOURCE" <<'PY'
from pathlib import Path
import hashlib, sys
p = Path(sys.argv[1])
for name, sha in [('M630DA.bin','10204a3cb9b9a2229d956de12ad9497b8845097ea4750522337569587bf048a4'),
                  ('M630DA.cue','8b8ca840931487d9cd6919cc2ec3dc698bf3d50a3e331733ef8415920526cba0')]:
    with (p / name).open('rb') as f:
        if hashlib.file_digest(f, 'sha256').hexdigest() != sha:
            raise SystemExit(f'Forkert SHA256: {name}')
# Verified single MODE1/2352 data track; never modify the original BIN/CUE.
with (p / 'M630DA.bin').open('rb') as src, (p / 'M630DA.iso.part').open('wb') as dst:
    while sector := src.read(2352):
        if len(sector) != 2352:
            raise SystemExit('Ufuldstændig sektor')
        dst.write(sector[16:2064])
(p / 'M630DA.iso.part').replace(p / 'M630DA.iso')
PY
7z x -y -o"$RUNTIME/cdrom" "$SOURCE/M630DA.iso" > "$RUNTIME/logs/extract.log"
[[ -s "$RUNTIME/cdrom/SETUP.EXE" && -s "$RUNTIME/cdrom/DATA2.CAB" ]]
if [[ "$LAUNCH" == 1 ]]; then
    exec env SOLUR_RUNTIME_DIR="$RUNTIME" SOLUR_MODE=setup "$HERE/launch.sh"
fi
printf 'Medier klar. Kør SOLUR_MODE=setup %s/launch.sh for original installation.\n' "$HERE"
