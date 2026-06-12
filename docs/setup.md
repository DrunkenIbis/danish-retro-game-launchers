# Setup workflow

1. Clone this repo.
2. Put legally obtained game media in `~/retro-game-files/<game-id>/` or `local/sources/<game-id>/`.
3. Run the game wrapper from `games/<game-id>/launch.sh`.
4. Import `games/<game-id>/lutris.yml` when the recipe includes one.

Runtime files and Wine prefixes belong in `~/retro-game-runtime/<game-id>/` or ignored `local/runtime/<game-id>/`.

## Generic ISO installer pattern

For games where setup is "use existing ISO, download a reference ISO, or import a physical CD/DVD", use `scripts/iso-installer.sh` instead of copying a full installer per game.

A game-specific `install.sh` should only set metadata and validation rules, then delegate:

```sh
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="example-game"
GAME_TITLE="Example Game"
INSTALLER_DOWNLOAD_URL="https://example.invalid/Example.iso"
INSTALLER_DOWNLOAD_LABEL="archive.org reference-linket"
INSTALLER_ISO_NAME="Example.iso"
INSTALLER_ISO_ENV_VAR="EXAMPLE_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="EXAMPLE_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="EXAMPLE_CD_DEVICE"
INSTALLER_REQUIRED_IMAGE_PATHS=(
  "GAME.EXE"
  "DATA/INTRO.DAT"
)

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
```

`INSTALLER_REQUIRED_IMAGE_PATHS` should contain the files the launcher needs to work. This catches wrong downloads, wrong CDs, failed imports, or renamed images before the user reaches DOSBox/Wine.

The generic installer supports:

```sh
./install.sh                    # interactive
./install.sh --existing         # validate existing ISO
./install.sh --download         # download and validate
./install.sh --cd /dev/sr0      # import physical CD/DVD and validate
./install.sh --iso /path/x.iso  # override ISO path
./install.sh --no-launch        # prepare only
```
