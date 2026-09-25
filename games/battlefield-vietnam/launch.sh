#!/usr/bin/env bash
# Recommended, user-confirmed disk-free 1.21 + optional SiMPLE runtime.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
case "${1:-game}" in
  game)
    export BFV_FOLDER_RUNTIME="${BFV_FOLDER_RUNTIME:-$(retro_runtime_dir "$ROOT" battlefield-vietnam)/simple121-ge7}"
    [[ -f "$BFV_FOLDER_RUNTIME/prefix/system.reg" ]] || { printf '%s\n' 'Disk-free runtime missing. Follow README: original install, official 1.2/1.21 patches, prepare-simple.sh.' >&2; exit 1; }
    exec "$HERE/launch_folder.sh"
    ;;
  setup|autorun|check|dry-run) exec "$HERE/launch_physical.sh" "$@";;
  *) printf '%s\n' 'Usage: launch.sh [game|setup|autorun|check|dry-run]; physical game: launch_physical.sh game' >&2; exit 1;;
esac
