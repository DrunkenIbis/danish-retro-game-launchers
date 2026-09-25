#!/usr/bin/env bash
# Dedicated disk-free Secret Weapons entry point; other variants stay separate.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
export BF1942_SIMPLE_RUNTIME="${BF1942_SW_SIMPLE_RUNTIME:-$(retro_runtime_dir "$ROOT" battlefield-1942)/secret-weapons-simple161b}"
GAME="$BF1942_SIMPLE_RUNTIME/prefix/drive_c/Program Files/EA GAMES/Battlefield 1942"
[[ -f "$GAME/Mods/XPack2/Archives/bf1942/Levels/Telemark.rfa" && -f "$GAME/Mods/XPack2/init.con" ]] || { printf 'Missing Secret Weapons game data; install original expansion and prepare its separate SiMPLE copy first\n' >&2; exit 1; }
exec "$HERE/launch_simple.sh" +game XPack2 "$@"
