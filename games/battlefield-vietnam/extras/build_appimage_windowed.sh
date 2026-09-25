#!/usr/bin/env bash
# Separate private virtual-desktop variant; reuse the shared build pipeline.
set -Eeuo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
exec "$HERE/build_appimage.sh" --windowed "$@"
