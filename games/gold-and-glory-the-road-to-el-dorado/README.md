# Gold and Glory: The Road to El Dorado (Windows, 2000)

Status: user-confirmed working launcher; AppImage smoke-tested
Runner: local Wine-GE 8-26 preferred; `wine32` fallback
Source: ISO CD image (`ED_CD`, Windows CD-ROM)

This directory contains only the compatibility recipe. It does not contain the game ISO, extracted CD data, Wine prefix, logs, screenshots, AppDirs, AppImages, or other runtime/build output.

## Quick start

From this directory:

```sh
./install.sh --download --no-launch
./launch.sh
```

The installer downloads/validates `ED_CD.iso` into the ignored source directory. Runtime extraction, Wine prefixes, and manual installed-copy experiments stay under `local/runtime/gold-and-glory-the-road-to-el-dorado/`.

## Private files

Default private paths:

```text
local/sources/gold-and-glory-the-road-to-el-dorado/ED_CD.iso
local/runtime/gold-and-glory-the-road-to-el-dorado/cdrom/
local/runtime/gold-and-glory-the-road-to-el-dorado/wineprefix32/
local/runtime/gold-and-glory-the-road-to-el-dorado/wine-ge-prefix/
local/runners/wine-ge-8-26/
local/appimage-dist/gold-and-glory-the-road-to-el-dorado/gold-and-glory-the-road-to-el-dorado-x86_64.AppImage
```

Override examples:

```sh
GGED_ISO=/path/to/ED_CD.iso ./launch.sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime ./launch.sh
```

## Installer modes

```sh
./install.sh                 # interactive
./install.sh --download      # download ISO, validate, then launch
./install.sh --download --no-launch
./install.sh --existing --no-launch
./install.sh --iso /path/to/ED_CD.iso --existing --no-launch
```

Reference URL used by `--download`:

```text
https://archive.org/download/edc2000/ED_CD.iso
```

## Launcher modes

```sh
./launch.sh                  # default: GGED_MODE=cdgame
GGED_MODE=prepare ./launch.sh
GGED_MODE=installed ./launch.sh
GGED_MODE=setup ./launch.sh
GGED_MODE=kill ./launch.sh
```

The default launcher:

- loop-mounts the original ISO through `udisksctl`, maps its mountpoint as Wine `D:`, and maps `D::` to the readable ISO when using Wine-GE
- prefers local Wine-GE 8-26, then falls back to `wine32`/`wine`
- initializes a dedicated Wine-GE prefix by default
- sets Wine Windows version to `win98`
- maps the loop-mounted original ISO as Wine drive `D:` with volume label `ED_CD`
- starts the real game executable from the CD context inside a centered `640x480` Wine Explorer desktop: `D:\\engine\\linc\\engine.exe`

`GGED_CD_BACKEND=loop` is the default because the game's CD detector rejects an extracted-directory mapping even when `vol d:` reports `ED_CD`. Use `GGED_CD_BACKEND=extract` only as a diagnostic fallback; it reproduces the in-game “Please insert El Dorado CD” prompt. The loop device and mount are removed when the launcher exits or is interrupted.

`AUTORUN.INF` points to `setup.exe`; inspection showed the actual game executable is `engine/linc/engine.exe`. `setup2.exe` strings show the installed target as `C:\ElDorado\engine\linc\engine.exe`, so `GGED_MODE=installed` manually copies the CD `engine/` tree into that location for diagnostics.

## Verified evidence and blocker

Verified:

- ISO downloaded from the reference URL and identified as ISO 9660 volume `ED_CD`.
- ISO contents were inspected before selecting a launcher path.
- Required paths exist, including:
  - `autorun.inf`
  - `setup.exe`
  - `Setup2.exe`
  - `engine/eldorado.ini`
  - `engine/linc/engine.exe`
  - `engine/linc/binkw32.dll`
  - `g/music.clu`, `g/samples.clu`, `g/speech.clu`
  - Bink movie files under `gmovies/` and `movies/`
- The extracted-directory backend created a real Wine/X11 game window but stopped at the in-game `Please insert El Dorado CD` dialog despite `vol d:` showing `ED_CD`.
- The loop-backed ISO backend (`D:` -> mounted ISO, `D::` -> `/dev/loopN`) passes that CD dialog and reaches the Light & Shadow Production splash screen.
- Wine Explorer virtual-desktop launch was tested and failed on this host with an X11 `BadWindow` error, so the recipe defaults to direct `cmd /c` mode rather than Wine Explorer desktop mode.
- Manual installed-copy launch from `C:\ElDorado\engine\linc\engine.exe` was tested and hit Wine debugger / access-violation evidence instead of proven gameplay.

Hard blocker / current status:

```text
Couldn't get first exception for process ... C:\ElDorado\engine\linc\engine.exe
No backtrace available
Exception c0000005
Wine build: wine-11.0 (Staging), Platform: i386, Version: Windows 98
```

The user confirmed that the current default launcher now runs the game in the intended centered 640×480 Wine desktop. The Wine-GE path uses a separate prefix and maps its readable ISO image as `D::`, while `D:` remains the loop-mounted original disc. This avoids Wine-GE's raw `/dev/loopN` permission error and preserves the original CD label check.

Do not mark this game as working until a real interactive in-game scene is visible and controllable and the known invisible-model risk has been checked.

## AppImage status

AppImage packaging is implemented in `extras/build_appimage.sh` and uses `scripts/wine-appimage-builder.sh` plus the verified local Wine-GE runner.

Build:

```sh
./extras/build_appimage.sh
```

Verified artifact:

```text
local/appimage-dist/gold-and-glory-the-road-to-el-dorado/gold-and-glory-the-road-to-el-dorado-x86_64.AppImage
```

The AppImage smoke test used a fresh `XDG_DATA_HOME`, copied the ISO to writable per-user state before `udisksctl loop-setup`, launched Wine from `/tmp/.mount_*/game/wine-ge/bin/`, and reached a `GoldGlory - Wine desktop` window with `engine.exe` running. A timeout exit is expected for the bounded smoke test because the game remains open.
