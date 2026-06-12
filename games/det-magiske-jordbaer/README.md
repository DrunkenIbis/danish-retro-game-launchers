# Det Magiske Jordbær

Status: working recipe  
Runner: DOSBox-Staging

This directory contains only the compatibility recipe. It does not contain the game ISO or extracted game files.

## First-time setup

Run the interactive setup script:

```sh
cd games/det-magiske-jordbaer
./install.sh
```

It will ask whether you want to:

1. use an ISO that is already present,
2. download the ISO from the archive.org reference link, or
3. import a physical CD/DVD by creating a local ISO image.

If an ISO already exists, the script asks whether to reuse it or replace it via download/CD import.

Default private ISO path:

```text
local/sources/det-magiske-jordbaer/DetMagiskeJordbaer.iso
```

Default runtime/extracted-data path:

```text
local/runtime/det-magiske-jordbaer/
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

Or with external private folders:

```sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files \
RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime \
./games/det-magiske-jordbaer/launch.sh
```

## Lutris

Import `lutris.yml` as a local Lutris install script/config. The wrapper remains the canonical game entry point; `install.sh` is for first-time ISO acquisition/import.

## AppImage build

After the game has been prepared locally, build a mostly self-contained x86_64 AppImage:

```sh
./extras/build_appimage.sh
```

Useful variants:

```sh
./extras/build_appimage.sh --appdir-only   # build and verify AppDir only
./extras/build_appimage.sh --no-download   # require local appimagetool/cache
```

Outputs are ignored by Git:

- AppDir: `extras/build/det-magiske-jordbaer.AppDir`
- AppImage: `extras/dist/det-magiske-jordbaer-x86_64.AppImage`

The AppImage bundles the local extracted game files plus the official DOSBox-Staging Linux x86_64 runtime. It still needs a reasonably compatible Linux host with glibc/kernel, OpenGL and audio support. Save/config files are kept outside the read-only AppImage in `~/.local/share/det-magiske-jordbaer/`.

Only distribute an AppImage made this way if you have the right to distribute the bundled game data.

## Reference link

Archive.org reference/download URL used by `install.sh`:

```text
https://archive.org/download/det-magiske-jordbaer/DetMagiskeJordb%C3%A6r.iso
```

Verify legal status in your country and only use copies you have the right to use.
