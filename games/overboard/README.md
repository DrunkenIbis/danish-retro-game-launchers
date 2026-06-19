# Overboard! / Shipwreckers! (PC ENG)

Status: installer and launcher verified; game still blocked by original-CD validator under Wine  
Runner: Wine (`wine32` preferred)  
Source: ZIP containing mixed-mode BIN/CUE CD image

This directory contains only the compatibility recipe. It does not contain the game ZIP, BIN/CUE, converted ISO, extracted CD data, Wine prefix, screenshots, logs, or build output.

## Quick start

From this directory:

```sh
./install.sh --download --no-launch
./launch.sh
```

The installer downloads `OVERBOARD.zip` from the Archive.org reference URL into the ignored source directory, extracts the embedded `OVERBOARD.bin`/`OVERBOARD.cue`, keeps those original mixed-mode files for launcher tests, converts only the first `MODE2/2352` data track to `OVERBOARD.iso`, and validates the files needed by the launcher before Wine starts.

## Private files

Default private paths:

```text
local/sources/overboard/OVERBOARD.zip
local/sources/overboard/OVERBOARD.bin
local/sources/overboard/OVERBOARD.cue
local/sources/overboard/OVERBOARD.iso
local/runtime/overboard/cdrom/
local/runtime/overboard/wineprefix32/
```

Override examples:

```sh
OVERBOARD_ZIP=/path/to/OVERBOARD.zip ./launch.sh
OVERBOARD_BIN=/path/to/OVERBOARD.bin OVERBOARD_CUE=/path/to/OVERBOARD.cue ./launch.sh
OVERBOARD_ISO=/path/to/OVERBOARD.iso OVERBOARD_MEDIA_MODE=iso ./launch.sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime ./launch.sh
```

## Installer modes

```sh
./install.sh                 # interactive
./install.sh --download      # download ZIP, convert data track, validate, then launch
./install.sh --download --no-launch
./install.sh --existing --no-launch
./install.sh --iso /path/to/OVERBOARD.iso --existing --no-launch
```

For this Archive.org item, `--download` uses:

```text
https://archive.org/download/overboard_202506/OVERBOARD.zip
```

## Launcher modes

```sh
./launch.sh                  # default: OVERBOARD_MODE=game
OVERBOARD_MODE=prepare ./launch.sh
OVERBOARD_MODE=autorun ./launch.sh
OVERBOARD_MODE=setup ./launch.sh
OVERBOARD_MODE=kill ./launch.sh
```

The default launcher keeps using the extracted data files as Wine drive `D:` so `D:\\OB.EXE` and the resource tree stay visible, but it now prefers the original `OVERBOARD.bin` as the backing block device for `D::` when available (`OVERBOARD_MEDIA_MODE=cuebin`). That is the closest approximation this Linux setup can provide to original BIN/CUE media without a dedicated mixed-mode CD emulator. Set `OVERBOARD_MEDIA_MODE=iso` to force the older ISO-only path.

## Notes and current blocker

The original BIN/CUE is a mixed-mode CD: track 1 is `MODE2/2352` PC data and the later tracks are CD audio. This recipe converts and launches the data track, but original CD audio playback is not preserved by this data-only ISO conversion.

Current verified launch result on this Fedora/Wine setup:

```text
Overboard! CD Validator
OVERBOARD! CD NOT PRESENT
Please place the Overboard! CD into your CD-ROM drive.
```

That dialog still appears even after:
- converting the first data track correctly to ISO
- setting the ISO volume label to `OVERBOARD`
- mapping Wine `D:` as `cdrom`
- launching from `D:\OB.EXE`
- testing both an extracted CD directory and a real loop-mounted ISO with `d::` pointing at `/dev/loop0`
- testing a cue/bin-backed Wine mapping where the extracted data stay on `D:` but `d::` points at a loop device for the original `OVERBOARD.bin`
- reproducing the same CD-check failure on Windows 10 from a mounted `OVERBOARD.cue` ProcMon capture (`Logfile.PML`)

Extra debug evidence from bounded runs:
- `wine32 cmd /c "cd /d d:\\ && OB.EXE"` can exit `0`
- `OVERBOARD_VIRTUAL_DESKTOP=1 ./launch.sh` can exit `1`
- `wine32 start /exec explorer /desktop=Overboard,800x600 D:\\OB.EXE` can also exit `1`
- `OVERBOARD_MEDIA_MODE=cuebin ./launch.sh` still shows the same `Overboard! CD Validator` dialog and exits `1`
- ISO/data-track runs showed `fixme:mcicda:MCICDA_GetError Unknown mode 1`
- cue/bin-backed runs also showed `fixme:vxd:__wine_vxd_open Unknown/unsupported VxD L"d:.vxd"`
- explorer/desktop launch also showed the same `d:.vxd` signal

So the recipe is now honest and reproducible, but the title is still blocked by a stronger original-CD check than a plain data-track ISO satisfies. The most promising next direction is true mixed-mode CD emulation (data track + audio TOC), not more path/registry churn.

## Lutris

Import `lutris.yml` as a local Lutris install script/config. The wrapper remains the canonical entry point.
