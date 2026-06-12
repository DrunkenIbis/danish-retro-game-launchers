#!/usr/bin/env bash
set -euo pipefail

recipe_root() {
  cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd
}

repo_root_from_game_dir() {
  local dir="$1"
  cd -- "$dir/../.." && pwd
}

retro_source_dir() {
  local repo="$1" game_id="$2"
  printf '%s
' "${RETRO_GAME_SOURCE_DIR:-$repo/local/sources}/$game_id"
}

retro_runtime_dir() {
  local repo="$1" game_id="$2"
  printf '%s
' "${RETRO_GAME_RUNTIME_DIR:-$repo/local/runtime}/$game_id"
}
