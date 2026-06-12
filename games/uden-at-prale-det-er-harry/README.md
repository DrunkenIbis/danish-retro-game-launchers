# Uden at prale, det er Harry

Status: recipe migrated from an existing local working/debug folder.  
Runner: wine

This directory contains only the compatibility recipe. It does not contain the game.

## First-time setup

Run the installer/importer:

```sh
cd games/uden-at-prale-det-er-harry
./install.sh
```

It can:

1. use an already prepared ISO,
2. download the BIN/CUE pair from the reference links and convert it to ISO, or
3. import a physical CD/DVD directly to ISO.

Default private source paths:

```text
local/sources/uden-at-prale-det-er-harry/uden-at-prale-det-er-harry.bin
local/sources/uden-at-prale-det-er-harry/uden-at-prale-det-er-harry.cue
local/sources/uden-at-prale-det-er-harry/uden-at-prale-det-er-harry.iso
```

Default runtime path:

```text
local/runtime/uden-at-prale-det-er-harry/
```

Both are ignored by Git.

## Non-interactive examples

```sh
./install.sh --download --no-launch
./install.sh --existing --no-launch
./install.sh --cd /dev/sr0 --no-launch
```

## Run

```sh
./launch.sh
```

Or with external private folders:

```sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files \
RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime \
./games/uden-at-prale-det-er-harry/launch.sh
```

The wrapper extracts the ISO to the ignored runtime folder, creates/reuses a Wine prefix, silently installs the Inno Setup payload to `C:\Harry` when needed, maps the extracted CD as `D:` with the `HARRY` label, and launches `harry.exe` in a Wine virtual desktop.

Useful modes:

```sh
HARRY_MODE=game ./launch.sh      # default installed game
HARRY_MODE=cdmenu ./launch.sh    # CD menu fallback
HARRY_MODE=setup ./launch.sh     # visible installer
HARRY_MODE=kill ./launch.sh      # stop the Wine prefix
```

## Lutris

If `lutris.yml` exists, import it as a local Lutris install script/config. The wrapper remains the canonical entry point.

## Reference links

The recipe may include search/reference links only. Verify legal status and provide your own copy.
