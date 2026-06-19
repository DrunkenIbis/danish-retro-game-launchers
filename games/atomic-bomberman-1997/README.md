# Atomic Bomberman (PC, 1997)

Status: launcher and AppImage verified to reach the real Atomic Bomberman main menu under Wine  
Runner: Wine (`wine32` preferred)  
Source: ISO CD image

This directory contains only the compatibility recipe. It does not contain the game ISO, extracted CD data, Wine prefix, logs, screenshots, or build output.

## Quick start

From this directory:

```sh
./install.sh --download --no-launch
./launch.sh
```

The installer downloads `Atomic Bomberman.ISO` from the Archive.org reference URL into the ignored source directory, validates the files the launcher really needs, and leaves the actual extraction/runtime state under `local/runtime/atomic-bomberman-1997/`.

## Private files

Default private paths:

```text
local/sources/atomic-bomberman-1997/Atomic Bomberman.ISO
local/runtime/atomic-bomberman-1997/cdrom/
local/runtime/atomic-bomberman-1997/wineprefix32/
```

Override examples:

```sh
AB_ISO=/path/to/Atomic\ Bomberman.ISO ./launch.sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime ./launch.sh
```

## Installer modes

```sh
./install.sh                 # interactive
./install.sh --download      # download ISO, validate, then launch
./install.sh --download --no-launch
./install.sh --existing --no-launch
./install.sh --iso /path/to/Atomic\ Bomberman.ISO --existing --no-launch
```

Reference URL used by `--download`:

```text
https://archive.org/download/atomic-bomberman_202504/Atomic%20Bomberman.ISO
```

## Launcher modes

```sh
./launch.sh                  # default: AB_MODE=game
AB_MODE=prepare ./launch.sh
AB_MODE=autorun ./launch.sh
AB_MODE=setup ./launch.sh
AB_MODE=kill ./launch.sh
```

The default launcher:
- extracts the ISO to the private runtime CD-ROM directory
- uses a dedicated Wine prefix
- prefers `wine32`
- sets Wine Windows version to `win98`
- maps the extracted CD as Wine drive `D:` with volume label `BOMBRMAN`
- starts `D:\BM95.EXE` inside an 800x600 Wine virtual desktop

## Validation note

The recipe was validated in two stages:

1. Native launcher validation reached the real in-game memory-model chooser:

```text
Please select Bomberman memory model:
  Enhanced (32mb or more of RAM)
  Normal   (less than 32mb of RAM)
```

2. AppImage validation went further and reached the real Atomic Bomberman main menu.

Observed AppImage-launched processes included:

```text
./atomic-bomberman-1997-x86_64.AppImage
C:\windows\system32\explorer.exe /desktop=AtomicBomberman,800x600 D:\BM95.EXE
D:\BM95.EXE
```

The captured AppImage window showed the actual game menu entries:

```text
Start Game
Start Network Game
Join Network Game
Options
About Bomberman
Online Manual
Exit Bomberman
```

That proves both the repo launcher and the packaged AppImage launch the real game executable rather than just Wine setup, the installer, or a blank Wine desktop.

## AppImage build

Build command:

```sh
./extras/build_appimage.sh
```

Built artifact:

```text
extras/dist/atomic-bomberman-1997-x86_64.AppImage
```

The build script follows the repository's shared Wine AppImage helper pattern via:

```text
scripts/wine-appimage-builder.sh
```