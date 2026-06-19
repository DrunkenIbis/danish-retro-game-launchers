# Magnus & Myggen: På Skattesjov

Status: blocked after runtime starts: the tested media opens an expired SuperStarter/trial dialog instead of gameplay  
Runner: Wine, manual InstallShield CAB extraction from BIN/CUE media

This directory contains only the compatibility recipe. It does not contain the BIN/CUE files, converted ISO, extracted game files, Wine prefix, logs, screenshots, or other runtime artifacts.

## Current blocker

The launcher can convert the archive.org BIN/CUE image, extract the InstallShield payload, and start the real Director projector (`mm8main.exe`). The program creates a real game window titled `Magnus og Myggen - Skattesjov`, so Wine is getting past extraction and resource loading.

However, the tested archive.org media then immediately opens a game-owned modal titled `Besked fra IVANOFF Interactive` with the expired trial text:

```text
Tiden på dit prøvespil er udløbet.
Du har nu følgende muligheder:
1. Luk dette vindue og prøv et andet Magnus og Myggen spil.
2. Køb spillet ved at klikke på [Køb spil] i SuperStarteren
```

Evidence gathered:

- `mm8main.exe` starts and creates `WM_NAME = "Magnus og Myggen - Skattesjov"`.
- The blocking modal is also owned by `mm8main.exe` and has `WM_NAME = "Besked fra IVANOFF Interactive"`.
- Wine `+file,+reg` logs show `C:\Skattesjov\mydlg.cxt` is opened successfully.
- The projector queries `HKLM\Software\Ivanoff interactive\mm8` / `HKLM\Software\IVANOFF Interactive\MM8` values and the shipped code contains SuperStarter/trial fields such as `gRegistered`, `gMinutes`, `used_minutes`.
- The same family of SuperStarter logic is present on the CD as `MMSUPER.EXE`.

Because bypassing that gate would be licence/trial circumvention, this recipe intentionally stops at the compatibility boundary. It prepares the runtime and documents the blocker, but does not patch the executable or forge registration/trial state.

## What was identified

The archive.org download is a BIN/CUE pair:

```text
SS12DK.cue: TRACK 01 MODE2/2352
SS12DK.bin: 72.8 MiB data track
```

The launcher converts the MODE2/2352 track into a normal ISO by taking the 2048-byte Form 1 payload from offset 24 in each 2352-byte sector.

Converted ISO evidence:

```text
ISO 9660 CD-ROM filesystem data 'SS12DK'
Volume id: SS12DK
```

CD-root layout:

```text
AUTORUN.INF      open=launcher.exe
CD.SYS
DATA1.CAB
DATA1.HDR
DATA2.CAB
HELP.RTF
II.ICO
IKERNEL.EX_
INFO.RTF
LAUNCHER.EXE
LAYOUT.BIN
MKCAPDIR.EXE
MM.ICO
MMSUPER.EXE
MMSUPER.ICO
SETUP.BMP
SETUP.EXE
SETUP.INI
SETUP.INX
```

Manual extraction with `unshield l DATA1.CAB` shows the useful game files:

```text
Files All DK/mm8main.exe
Files All DK/mydlg.cxt
Files All DK/mm8.HLP
Files All/Xtras/*.x32
```

The launcher copies those into a writable runtime tree and mirrors it into `C:\Skattesjov` so Director can find `mydlg.cxt` and `xtras/` consistently.

## First-time setup

Run the interactive setup script:

```sh
cd games/magnus-myggen-paa-skattesjov
./install.sh
```

It will ask whether you want to:

1. use an existing converted ISO or existing BIN/CUE,
2. download `SS12DK.bin` and `SS12DK.cue` from the archive.org reference link, or
3. import a physical CD/DVD by creating a local ISO image.

Default private source paths:

```text
local/sources/magnus-myggen-paa-skattesjov/SS12DK.bin
local/sources/magnus-myggen-paa-skattesjov/SS12DK.cue
local/sources/magnus-myggen-paa-skattesjov/SS12DK.iso
```

Default runtime/extracted-data path:

```text
local/runtime/magnus-myggen-paa-skattesjov/
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
MM8_MODE=prepare ./launch.sh       # convert/extract/install runtime and prepare Wine prefix only
MM8_MODE=game ./launch.sh          # default: start C:\Skattesjov\mm8main.exe
MM8_MODE=launcher ./launch.sh      # original CD launcher fallback
MM8_MODE=superstarter ./launch.sh  # original SuperStarter fallback
MM8_MODE=setup ./launch.sh         # original setup fallback
MM8_MODE=kill ./launch.sh          # stop this Wine prefix
```

Or with external private folders:

```sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files \
RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime \
./games/magnus-myggen-paa-skattesjov/launch.sh
```

## Lutris

Import `lutris.yml` as a local Lutris install script/config. The wrapper remains the canonical game entry point; `install.sh` is for first-time BIN/CUE acquisition/import.

## Reference link

Archive.org reference/download URL used by `install.sh`:

```text
https://archive.org/download/magnus-myggen-paa-skattesjov/
```

Verify legal status in your country and only use copies you have the right to use.
