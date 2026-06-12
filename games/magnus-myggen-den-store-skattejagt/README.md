# Magnus & Myggen: Den Store Skattejagt

Status: launches in centered Wine desktop; gameplay is not screenshot-verified  
Runner: Wine, manual InstallShield CAB extraction from BIN/CUE media

This directory contains only the compatibility recipe. It does not contain the BIN/CUE files, converted ISO, extracted game files, Wine prefix, logs, screenshots, or other runtime artifacts.

## What this recipe does

The archive.org release is a BIN/CUE image:

```text
MM2NORD.cue
MM2NORD.bin
```

`install.sh` can download those files and converts the single `MODE1/2352` data track to a normal ISO. `launch.sh` then:

1. extracts the ISO into ignored runtime storage,
2. maps that extracted CD as Wine drive `D:`,
3. extracts the real Danish game executable from `DATA1.CAB` with `unshield`,
4. writes the required IVANOFF `MM2` registry values so the game uses:
   - `D:\MM2.DAT`
   - `D:\DK\MM2LNG.DAT`
5. starts `MM2RUN.EXE` under a 32-bit Wine prefix set to Windows 98 compatibility.

The original `AUTORUN.INF` opens `LAUNCHER.EXE`, but the reliable path bypasses InstallShield and starts the real game executable directly.

## First-time setup

Run the interactive setup script:

```sh
cd games/magnus-myggen-den-store-skattejagt
./install.sh
```

It will ask whether you want to:

1. use an existing converted ISO or existing BIN/CUE,
2. download `MM2NORD.bin` and `MM2NORD.cue` from the archive.org reference link, or
3. import a physical CD/DVD by creating a local ISO image.

Default private source paths:

```text
local/sources/magnus-myggen-den-store-skattejagt/MM2NORD.bin
local/sources/magnus-myggen-den-store-skattejagt/MM2NORD.cue
local/sources/magnus-myggen-den-store-skattejagt/MM2NORD.iso
```

Default runtime/extracted-data path:

```text
local/runtime/magnus-myggen-den-store-skattejagt/
```

Both are ignored by Git.

## Non-interactive examples

Download and convert from the reference link:

```sh
./install.sh --download --no-launch
```

Use existing source files:

```sh
./install.sh --existing --no-launch
```

Import from a CD/DVD drive:

```sh
./install.sh --cd /dev/sr0 --no-launch
```

## Run after setup

```sh
./launch.sh
```

Useful modes:

```sh
MM2_MODE=prepare ./launch.sh   # convert/extract/install runtime and prepare Wine prefix only
MM2_MODE=game ./launch.sh      # default: start MM2RUN.EXE directly
MM2_MODE=launcher ./launch.sh  # original CD launcher fallback
MM2_MODE=setup ./launch.sh     # original setup fallback
MM2_MODE=kill ./launch.sh      # stop this Wine prefix
```

Or with external private folders:

```sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files \
RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime \
./games/magnus-myggen-den-store-skattejagt/launch.sh
```

## Lutris

Import `lutris.yml` as a local Lutris install script/config. The wrapper remains the canonical game entry point; `install.sh` is for first-time BIN/CUE acquisition/import.

## AppImage

After preparing the local runtime, build a self-contained Wine AppDir/AppImage with:

```sh
./extras/build_appimage.sh
```

For a metadata/AppDir-only packaging check without creating the final large AppImage:

```sh
./extras/build_appimage.sh --appdir-only
```

The output goes under ignored `extras/build/`, `extras/dist/`, and `extras/.cache-appimage/`. The AppImage embeds the local game files and a prepared Wine prefix, so only build/distribute it for copies you have the right to package.

## Verification status

The moved recipe was tested from this repo, not only from the old debug folder. The wrapper gets past media conversion, CD extraction, manual InstallShield extraction, Wine prefix setup, registry/resource lookup, and starts the actual `MM2RUN.EXE` process. Wine logs confirm that `D:\MM2.DAT`, `D:\MM2.IDX`, `D:\DK\MM2LNG.DAT`, and `D:\DK\MM2LNG.IDX` open successfully.

Current verification: the game starts inside an 800x600 Wine virtual desktop window that is centered on the 3840x1080 X11 root. Process/window evidence shows `explorer.exe` owns `MagnusMyggen2 - Wine Desktop` and `MM2RUN.EXE` is running. The local screenshot capture still sees black content, so this recipe is not marked fully playable from automated evidence alone; the live user-facing display may show the game/audio correctly.

## Reference link

Archive.org reference/download URL used by `install.sh`:

```text
https://archive.org/download/magnus-myggen-den-store-skattejagt/
```

Verify legal status in your country and only use copies you have the right to use.
