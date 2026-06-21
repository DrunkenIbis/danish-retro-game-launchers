#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_DIR="${HARRY_RUNTIME_DIR:-$BASE_DIR/../../local/runtime/uden-at-prale-det-er-harry}"
WINEPREFIX="${HARRY_WINEPREFIX:-$RUNTIME_DIR/wineprefix}"
GAME_DIR="${HARRY_GAME_DIR:-$WINEPREFIX/drive_c/Harry}"
MOVIES="$GAME_DIR/movies"
BACKUP="$GAME_DIR/movies.original-iv32-backup"
if [[ ! -d "$BACKUP" ]]; then
  echo "Backup-mappe mangler: $BACKUP" >&2
  exit 1
fi
mkdir -p "$MOVIES"
shopt -s nullglob
avi_files=("$BACKUP"/*.avi)
shopt -u nullglob
if [[ ${#avi_files[@]} -eq 0 ]]; then
  echo "Ingen AVI-filer i backup: $BACKUP" >&2
  exit 1
fi

movie_requires_400x216() {
  case "$1" in
    intro_scene_new_1.avi|cutscene_1.avi|cutscene_2.avi|cutscene_3.avi|outro.avi) return 0 ;;
    *) return 1 ;;
  esac
}

for src in "${avi_files[@]}"; do
  dest="$MOVIES/$(basename "$src")"
  if movie_requires_400x216 "$(basename "$src")"; then
    ffmpeg -y -hide_banner -loglevel error -i "$src" -vf scale=400:216 -c:v msvideo1 -c:a pcm_s16le "$dest"
  else
    ffmpeg -y -hide_banner -loglevel error -i "$src" -c:v msvideo1 -c:a pcm_s16le "$dest"
  fi
done
echo "Originale AVI-filer transkodet til Microsoft Video 1 i: $MOVIES"
