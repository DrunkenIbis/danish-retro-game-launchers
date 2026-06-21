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

## AppImage build

After preparing the game locally, build a mostly self-contained x86_64 AppImage:

```sh
./extras/build_appimage.sh
```

Useful variants:

```sh
./extras/build_appimage.sh --appdir-only   # build and verify AppDir only
./extras/build_appimage.sh --no-download   # require local appimagetool/cache
```

Outputs are ignored by Git:

- AppDir: `extras/build/uden-at-prale-det-er-harry.AppDir`
- AppImage: `extras/dist/uden-at-prale-det-er-harry-x86_64.AppImage`

The AppImage bundles the extracted CD-ROM, a prepared Wine prefix with `C:\Harry`, and a copied Wine runtime. On first run it copies the prefix and CD-ROM data to `~/.local/share/uden-at-prale-det-er-harry/` so Wine can update drive mappings and the `HARRY` CD label even though the AppImage itself is read-only.

The launcher now regenerates every AVI in `movies/` from the backup copy and transcodes them to Microsoft Video 1 before launch. The longer 400x224 cutscene family (`intro_scene_new_1.avi`, `cutscene_*.avi`, and `outro.avi`) is also normalized to 400x216, because Director/Wine MCI can still report `intro_scene_new_1.avi` as an unsupported digital-video file when the MSVC transcode preserves the original 400x224 frame. This keeps Director Player on a format/geometry it can play inside the bundled Wine runtime and avoids the ticket/intro playback errors.

Only distribute an AppImage made this way if you have the right to distribute the bundled game data.

## Reference links

The recipe may include search/reference links only. Verify legal status and provide your own copy.
