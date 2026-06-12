# Magnus & Myggen: Quizkampen Superstarter

Status: blocked after runtime starts: the game opens a SuperStarter/licence dialog instead of gameplay  
Runner: Wine, manual InstallShield CAB extraction

This directory contains only the compatibility recipe. It does not contain the game ISO, extracted game files, Wine prefix, AppDir, AppImage, logs or screenshots.

## Current blocker

The launcher can extract and start the real Director projector, but that is not enough for this Superstarter release. The running game immediately opens a custom in-game modal titled `0` (or `Information` if those registry fields are changed), with a Magnus drawing and an `Ok` button. This is not a Wine crash and not a missing-window issue: the process and windows are real, but the title remains at the SuperStarter/licence gate.

Evidence gathered:

- `mm12main.exe` starts and creates `WM_NAME = "Quizkampen"`.
- The blocking modal is also owned by `mm12main.exe` and has `WM_NAME = "0"`.
- Wine `+file,+reg` logs show all Director `.cxt` casts and Xtras load successfully from `C:\Quizkampen`/`installed/`.
- The projector then queries `HKLM\Software\IVANOFF Interactive\mm12` values `reg_message`, `reg_caption`, and `appmanfile`, which are part of the title's SuperStarter/licence/app-manager logic.
- SuperStarter itself displays Quizkampen as `0 gratis minutter` / `Køb spil`, so this ISO appears to be a SuperStarter/demo shell rather than a standalone fully unlocked game copy.

Because bypassing that gate would be a no-CD/licence circumvention path, this recipe intentionally stops at the compatibility boundary: it prepares the runtime and documents the blocker, but does not patch the executable or forge licence state.

## What was identified

The archive.org ISO has volume label `Q122DK` and this CD-root layout:

- `AUTORUN.INF` with `open=launcher.exe`
- `LAUNCHER.EXE` and `SETUP.EXE` as PE32 Windows executables
- InstallShield payload: `DATA1.CAB`, `DATA1.HDR`, `DATA2.CAB`
- icon: `MM.ICO`

The robust launcher bypasses the visible InstallShield flow and manually extracts the real Director game runtime from `DATA1.CAB`:

- `Application_DK/mm12main.exe`
- `Application_DK/*.cxt`
- `Application/xtras/*.x32`

The smoke-tested runtime starts `mm12main.exe` directly with a win32 Wine prefix set to Windows 98 compatibility.

## First-time setup

Run the interactive setup script:

```sh
cd games/magnus-myggen-quizkampen-superstarter
./install.sh
```

It will ask whether you want to:

1. use an ISO that is already present,
2. download the ISO from the archive.org reference link, or
3. import a physical CD/DVD by creating a local ISO image.

Default private ISO path:

```text
local/sources/magnus-myggen-quizkampen-superstarter/Quizkampen Superstarter Version.iso
```

Default runtime/extracted-data path:

```text
local/runtime/magnus-myggen-quizkampen-superstarter/
```

Both are ignored by Git.

## Non-interactive examples

Use existing ISO:

```sh
./install.sh --existing
```

Download from the reference link:

```sh
./install.sh --download
```

Import from a CD/DVD drive:

```sh
./install.sh --cd /dev/sr0
```

Prepare/import only, without launching:

```sh
./install.sh --download --no-launch
```

## Run after setup

```sh
./launch.sh
```

Useful modes:

```sh
MMQ_MODE=prepare ./launch.sh   # extract/install runtime and prepare Wine prefix only
MMQ_MODE=game ./launch.sh      # default: start mm12main.exe
MMQ_MODE=launcher ./launch.sh  # original CD launcher fallback
MMQ_MODE=setup ./launch.sh     # original setup fallback
MMQ_MODE=kill ./launch.sh      # stop this Wine prefix
```

Or with external private folders:

```sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files \
RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime \
./games/magnus-myggen-quizkampen-superstarter/launch.sh
```

## Lutris

Import `lutris.yml` as a local Lutris install script/config. The wrapper remains the canonical game entry point; `install.sh` is for first-time ISO acquisition/import.

## AppImage build

`extras/build_appimage.sh` is kept as a packaging scaffold, but AppImage output is not marked working while the launcher remains blocked at the SuperStarter/licence dialog. Re-test the launcher with a legally unlocked/original copy before treating any AppImage as useful.

If you still need to inspect the packaging mechanics locally:

```sh
./extras/build_appimage.sh --appdir-only
```

Outputs are ignored by Git:

- AppDir: `extras/build/magnus-myggen-quizkampen-superstarter.AppDir`
- AppImage: `extras/dist/magnus-myggen-quizkampen-superstarter-x86_64.AppImage`

Only distribute an AppImage made this way if you have the right to distribute the bundled game data.

## Reference link

Archive.org reference/download URL used by `install.sh`:

```text
https://archive.org/download/magnus-myggen-quizkampen-superstarter-version/Quizkampen%20Superstarter%20Version.iso
```

Verify legal status in your country and only use copies you have the right to use.
