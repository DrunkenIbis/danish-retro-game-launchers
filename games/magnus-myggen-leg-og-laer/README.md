# Magnus & Myggen: Leg og Lær

Status: launcher starts and survives intro-skip crash test; blocked later by CD-check dialog.  
Runner: wine/winevdm

This directory contains only the compatibility recipe. It does not contain the game.

## Bring your own game files

Place your legally obtained game files in one of these locations:

```text
~/retro-game-files/magnus-myggen-leg-og-laer/
# or
local/sources/magnus-myggen-leg-og-laer/
```

See `recipe.yml` for expected metadata. Checksums still need to be filled in before publishing.

## Install/import

Put your ISO at:

```text
local/sources/magnus-myggen-leg-og-laer/Magnus-Myggen-Leg-og-Laer.iso
```

or import an original CD/DVD with:

```sh
./games/magnus-myggen-leg-og-laer/install.sh --cd /dev/sr0 --no-launch
```

If you already have the ISO in the source folder:

```sh
./games/magnus-myggen-leg-og-laer/install.sh --existing --no-launch
```

## Run

```sh
./games/magnus-myggen-leg-og-laer/launch.sh
```

The launcher writes all extracted/runtime data under `local/runtime/magnus-myggen-leg-og-laer/`. It starts the private installed copy `C:\\MAGNUS\\MAGNUS.EXE` by default, maps the original CD as `D:`, repairs MCI AVI registration, writes the legacy `system.ini`/`win.ini` files found in the known-good prefix, and patches only the private installed `MAGNUS.EXE` NE init-heap field to `0x2400`. It deliberately does not patch `MMSYS.DLL`.

`MM1_MODE=cdgame` is diagnostic only: direct `D:\\MAGNUS.EXE` can show the intro, but the unpatched CD executable still hits the Win16 `0xffffffff` page-fault crash after skipping/advancing the intro.

Current blocker: the verified `MM1_MODE=game` path no longer hits the `0xffffffff` page fault or `OPTLOAD`, but after repeated Escape presses it reaches a CD-check dialog asking for the original CD / correct CD-ROM drive. Do not mark the title fully playable until that dialog is resolved with a legitimate CD-drive mapping fix.

Useful modes:

```sh
MM1_MODE=game ./games/magnus-myggen-leg-og-laer/launch.sh      # default, patched installed-copy launch
MM1_MODE=cdgame ./games/magnus-myggen-leg-og-laer/launch.sh    # diagnostic direct D:\\MAGNUS.EXE; can still crash
MM1_EXE_HEAP=0x2400 ./games/magnus-myggen-leg-og-laer/launch.sh # default heap patch value
MM1_DRY_RUN=1 ./games/magnus-myggen-leg-og-laer/launch.sh      # print resolved paths
```

## Lutris

If `lutris.yml` exists, import it as a local Lutris install script/config. The wrapper remains the canonical entry point.

## Reference links

The recipe may include search/reference links only. Verify legal status and provide your own copy.
