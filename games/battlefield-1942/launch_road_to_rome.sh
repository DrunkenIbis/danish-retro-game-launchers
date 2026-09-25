#!/usr/bin/env bash
# Dedicated disk-free expansion entry point; base game's runtime stays separate.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
export BF1942_SIMPLE_RUNTIME="${BF1942_RTR_SIMPLE_RUNTIME:-$(retro_runtime_dir "$ROOT" battlefield-1942)/road-to-rome-simple161b}"
GAME="$BF1942_SIMPLE_RUNTIME/prefix/drive_c/Program Files/EA GAMES/Battlefield 1942"
[[ -f "$GAME/Mods/XPack1/Archives/Bf1942/Levels/cassino.rfa" && -f "$GAME/Mods/XPack1/init.con" ]] || { printf 'Missing Road to Rome game data; install original expansion and prepare its separate SiMPLE copy first\n' >&2; exit 1; }
exec "$HERE/launch_simple.sh" +game XPack1 "$@"
