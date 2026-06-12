#!/usr/bin/env bash
set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOVIES="$BASE_DIR/wineprefix_ge/drive_c/Harry/movies"
BACKUP="$BASE_DIR/wineprefix_ge/drive_c/Harry/movies.original-iv32-backup"
if [[ ! -d "$BACKUP" ]]; then
  echo "Backup-mappe mangler: $BACKUP" >&2
  exit 1
fi
cp -av "$BACKUP"/*.avi "$MOVIES"/
echo "Originale IV32 AVI-filer gendannet til: $MOVIES"
