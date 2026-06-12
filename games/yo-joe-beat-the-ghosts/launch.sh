#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF="${YOJOE_DOSBOX_CONF:-$SCRIPT_DIR/yo-joe.conf}"
if [[ ! -f "$CONF" ]]; then
  echo "Missing DOSBox config: $CONF" >&2
  exit 1
fi
if command -v dosbox-staging >/dev/null 2>&1; then
  exec dosbox-staging -conf "$CONF"
elif command -v dosbox >/dev/null 2>&1; then
  exec dosbox -conf "$CONF"
elif command -v flatpak >/dev/null 2>&1 && flatpak info io.github.dosbox-staging >/dev/null 2>&1; then
  exec flatpak run io.github.dosbox-staging -conf "$CONF"
else
  echo "DOSBox not found. Install dosbox-staging, dosbox, or Flatpak io.github.dosbox-staging." >&2
  exit 127
fi
