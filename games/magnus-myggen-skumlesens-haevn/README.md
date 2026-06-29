# Magnus & Myggen: Skumlesens Hævn

Status: blocked after runtime starts: the tested media opens a trial-expired dialog instead of gameplay  
Runner: Wine, manual InstallShield CAB extraction from BIN/CUE media

This directory contains only the compatibility recipe. It does not contain the BIN/CUE files, converted ISO, extracted game files, Wine prefix, logs, screenshots, or other runtime artifacts.

## Current blocker

The launcher can convert the archive.org BIN/CUE image, extract the InstallShield payload, build a local runtime tree, and start the real game executable (`mm3run.exe`) in a Wine 800x600 virtual desktop.

However, the tested archive.org media immediately shows a game-owned modal dialog:

```text
This trial game has expired.
```

Observed evidence:

- `M322DK.cue` is a single `TRACK 01 MODE1/2352` data image.
- Converted ISO is an ISO9660 CD-ROM with volume label `M322DK`.
- `AUTORUN.INF` opens `LAUNCHER.EXE`.
- `DATA1.CAB`/`DATA2.CAB` contain the actual runtime: `appfiles/mm3run.exe`, `appfiles/scripts/*.SCP`, `resfiles_DK/DK/*.DAT`, and `music/music/*.DAT`.
- `mm3run.exe` starts under Wine as a real process, but the visible 800x600 Wine desktop contains the modal `This trial game has expired.`.
- Strings in `mm3run.exe` include `This trial game has expired.`, `Software\\IVANOFF Interactive\\MM3`, `MusicPath`, `UseFullScreen`, and `settings.dat`.

Because bypassing a trial/licence gate would be circumvention, this recipe intentionally documents the blocker and does not patch the executable or forge registration/trial state. Do not call this recipe working until playable gameplay beyond this modal is verified with lawful media/state.

## What was identified

Archive.org reference media:

```text
M322DK.cue: TRACK 01 MODE1/2352
M322DK.bin: 328 MiB raw data track
```

Local hashes observed during implementation:

```text
1d27ec277b6f86db495b84ac466ee0d74857f5e23eb73cdf02d2ddcd1963cbad  M322DK.cue
554a0254eb9992cb528ec6fb249f61d9f6e9995074e67e547c64461dee23f4ff  M322DK.bin
```

The launcher converts the MODE1/2352 track into a normal ISO by taking the 2048-byte payload from offset 16 in each 2352-byte sector.

Converted ISO evidence:

```text
ISO 9660 CD-ROM filesystem data 'M322DK'
Volume id: M322DK
Volume size: 145870 sectors
```

CD-root essentials:

```text
AUTORUN.INF      open=launcher.exe
DATA1.CAB
DATA1.HDR
DATA2.CAB
LAUNCHER.EXE
MM.ICO
SETUP.EXE
SETUP.INI
SETUP.INX
DIRECTX/
```

Manual extraction with `unshield l DATA1.CAB` shows the useful game files:

```text
appfiles/mm3run.exe
appfiles/scripts/LOCATION.SCP
appfiles/scripts/OBJECT.SCP
appfiles/scripts/GRID.SCP
appfiles/scripts/LEVEL.SCP
appfiles_DK/mm3dk.hlp
resfiles_DK/DK/MYGGEN.DAT
resfiles_DK/DK/PLAYER.DAT
resfiles_DK/DK/SPIDER.DAT
resfiles_DK/DK/SYSTEM.DAT
resfiles_DK/DK/USER.DAT
resfiles_DK/DK/FIGHT.DAT
music/music/*.DAT
superstarter_DK/mmsuper.exe
```

The launcher copies these into a writable runtime tree and mirrors it into `C:\\Program Files\\Magnus & Myggen - Skumlesens Haevn` so `mm3run.exe` can find scripts, Danish resources, and music consistently.

## First-time setup

Run the interactive setup script:

```sh
cd games/magnus-myggen-skumlesens-haevn
./install.sh
```

It will ask whether you want to:

1. use an existing converted ISO or existing BIN/CUE,
2. download `M322DK.bin` and `M322DK.cue` from the archive.org reference link, or
3. import a physical CD/DVD by creating a local ISO image.

Default private source paths:

```text
local/sources/magnus-myggen-skumlesens-haevn/M322DK.bin
local/sources/magnus-myggen-skumlesens-haevn/M322DK.cue
local/sources/magnus-myggen-skumlesens-haevn/M322DK.iso
```

Default runtime/extracted-data path:

```text
local/runtime/magnus-myggen-skumlesens-haevn/
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
MM3_MODE=prepare ./launch.sh       # convert/extract/install runtime and prepare Wine prefix only
MM3_MODE=game ./launch.sh          # default: start C:\Program Files\...\mm3run.exe
MM3_MODE=launcher ./launch.sh      # original CD launcher fallback
MM3_MODE=setup ./launch.sh         # original InstallShield setup fallback
MM3_MODE=superstarter ./launch.sh  # extracted SuperStarter fallback
MM3_MODE=kill ./launch.sh          # stop this Wine prefix
```

Or with external private folders:

```sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files \
RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime \
./games/magnus-myggen-skumlesens-haevn/launch.sh
```

## Lutris

Import `lutris.yml` as a local Lutris install script/config. The wrapper remains the canonical game entry point; `install.sh` is for first-time BIN/CUE acquisition/import.

## AppImage status

Not implemented for this title yet. The direct Wine recipe is blocked by the trial-expired modal before gameplay, so packaging the same runtime as an AppImage would only preserve a known-blocked state. Next best AppImage step is to revisit packaging only after lawful media/state reaches real gameplay through `launch.sh`.

## Reference link

Archive.org reference/download URL used by `install.sh`:

```text
https://archive.org/download/magnus-myggen-skumlesens-haevn/
```

Verify legal status in your country and only use copies you have the right to use.
