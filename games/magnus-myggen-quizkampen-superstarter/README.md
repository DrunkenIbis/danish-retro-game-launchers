# Magnus & Myggen: Quizkampen Superstarter

Status: working recipe  
Runner: Wine, manual InstallShield CAB extraction

This directory contains only the compatibility recipe. It does not contain the game ISO, extracted game files, Wine prefix, AppDir, AppImage, logs or screenshots.

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

After the runtime has been prepared locally, build an AppDir/AppImage:

```sh
./extras/build_appimage.sh --appdir-only
./extras/build_appimage.sh
```

Outputs are ignored by Git:

- AppDir: `extras/build/magnus-myggen-quizkampen-superstarter.AppDir`
- AppImage: `extras/dist/magnus-myggen-quizkampen-superstarter-x86_64.AppImage`

The AppImage bundles the local extracted game files plus Wine runtime and a prepared Wine prefix. It still needs a reasonably compatible Linux host with glibc/kernel, X11/Wayland bridge, graphics and audio support. User state is copied outside the read-only AppImage to `~/.local/share/magnus-myggen-quizkampen-superstarter/`.

Only distribute an AppImage made this way if you have the right to distribute the bundled game data.

## Reference link

Archive.org reference/download URL used by `install.sh`:

```text
https://archive.org/download/magnus-myggen-quizkampen-superstarter-version/Quizkampen%20Superstarter%20Version.iso
```

Verify legal status in your country and only use copies you have the right to use.
