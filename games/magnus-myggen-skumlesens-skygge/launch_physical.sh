#!/usr/bin/env bash
# Compatibility alias for existing shortcuts; canonical logic is in launch.sh.
set -euo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec bash "$HERE/launch.sh" "$@"
