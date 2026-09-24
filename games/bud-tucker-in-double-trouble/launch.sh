#!/usr/bin/env bash
# Experimental ordinary-folder route; no optical drive or image mounted.
set -euo pipefail
GAME_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source "$GAME_DIR/../../scripts/common.sh"
REPO=$(repo_root_from_game_dir "$GAME_DIR")
BASE=$(retro_runtime_dir "$REPO" bud-tucker-in-double-trouble)
RUNTIME=${BUD_FOLDER_RUNTIME:-$BASE/folder}
SOURCE=$(retro_source_dir "$REPO" bud-tucker-in-double-trouble)
ISO=${BUD_ISO:-$SOURCE/BUD_USA.iso}
SEED=${BUD_INSTALLED_C:-$BASE/physical/c}
MODE=${1:-game}
[[ $MODE == prepare || $MODE == game ]] || { printf 'Usage: %s [prepare|game]\n' "$0" >&2; exit 2; }
mkdir -p "$RUNTIME/logs"
exec 9>"$RUNTIME/session.lock"
flock -n 9 || { printf 'Bud Tucker folder session is already running.\n' >&2; exit 1; }
if [[ $MODE == prepare ]]; then
  [[ -f "$ISO" && -f "$SEED/TUCKER/BUD.BAT" && -f "$SEED/G.IN" ]] || { printf 'Missing ISO or completed original installation. Run install.sh first.\n' >&2; exit 1; }
  [[ ! -e "$RUNTIME/c" && ! -e "$RUNTIME/cd-files" ]] || { printf 'Refusing to overwrite existing folder experiment. Select a new BUD_FOLDER_RUNTIME.\n' >&2; exit 1; }
  # Cooperate with original installer lock before copying writable C:.
  exec 8>"$(dirname -- "$SEED")/session.lock"
  flock -n 8 || { printf 'Close the original DOSBox session before copying its installation.\n' >&2; exit 1; }
  7z x -y "-o$RUNTIME/cd-files" "$ISO" >"$RUNTIME/logs/extraction.log"
  [[ -f "$RUNTIME/cd-files/TUCKER/INTRO.EXE" ]] || { printf 'Wrong image: missing TUCKER/INTRO.EXE.\n' >&2; exit 1; }
  cp -a -- "$SEED" "$RUNTIME/c"
  printf 'Prepared separate folder experiment: %s\n' "$RUNTIME"
  exit 0
fi
[[ -f "$RUNTIME/c/TUCKER/BUD.BAT" && -f "$RUNTIME/cd-files/TUCKER/INTRO.EXE" ]] || { printf 'Missing folder runtime. Run launch.sh prepare first.\n' >&2; exit 1; }
flatpak info io.github.dosbox-staging >/dev/null
python3 - "$GAME_DIR/dosbox.conf.in" "$RUNTIME" <<'PY'
from pathlib import Path
import sys
p = Path(sys.argv[2]).resolve()
if any(c in str(p) for c in '\n\r"'):
    sys.exit('Unsupported runtime path characters')
base = Path(sys.argv[1]).read_text().split('[autoexec]')[0]
# Both guest drives are ordinary local directories, not CD-ROM mappings.
commands = f'[autoexec]\n@echo off\nmount c "{p}/c"\nmount d "{p}/cd-files"\nc:\ncd \\TUCKER\ncall BUD.BAT\nexit\n'
(p/'folder.conf').write_text(base + commands)
PY
flatpak run --filesystem="$RUNTIME" --socket=x11 --nosocket=wayland --env=SDL_VIDEODRIVER=x11 \
  io.github.dosbox-staging --noprimaryconf --nolocalconf --conf "$RUNTIME/folder.conf" \
  >"$RUNTIME/logs/game-$(date +%Y%m%d-%H%M%S).log" 2>&1
