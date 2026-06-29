# Galactic Warrior Rats

Status: launcher verified; gameplay start visually confirmed by user  
Runner: DOSBox-Staging

This directory contains only the compatibility recipe. It does not contain the downloaded 7z archive, the floppy image, extracted DOS game files, screenshots or logs.

## First-time setup

```sh
cd games/galactic-warrior-rats
./install.sh --download --no-launch
```

`install.sh` stores the private source archive here by default:

```text
local/sources/galactic-warrior-rats/003318_galactic_warrior_rats.7z
```

It extracts the embedded `disk1.img` to a private source cache and extracts the DOS game files to:

```text
local/runtime/galactic-warrior-rats/game/
```

Both paths are ignored by Git.

## Non-interactive setup examples

Use an existing archive already placed at the default path:

```sh
./install.sh --existing --no-launch
```

Copy/import a local archive:

```sh
./install.sh --archive /path/to/003318_galactic_warrior_rats.7z --no-launch
```

Download and launch immediately:

```sh
./install.sh --download
```

## Run after setup

```sh
./launch.sh
```

Or with external private folders:

```sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files \
RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime \
./games/galactic-warrior-rats/launch.sh
```

## Identified media and launcher

Source archive inspected:

```text
003318_galactic_warrior_rats.7z
sha256: 44e67d11a9b7cd76f5553b3cbe6d618f64108cee05b0e26114632ad1e11ce4d1
```

Archive structure:

```text
003318_galactic_warrior_rats/disk1.img
```

The floppy image contains no `INSTALL.EXE`, `SETUP.EXE` or `.BAT` launcher. It contains `GWR.COM`, `GWR.EXE`, level/resource files and PCM samples.

Correct DOS launcher: `GWR.COM`.

Reason: `GWR.COM` contains the visible loader strings `GWR.EXE`, `Cannot find file GWR.EXE` and `Not enough memory to run programme`; `GWR.EXE` is the packed MZ/PKLITE game payload. The launcher therefore starts `GWR.COM` from the extracted floppy root.

## DOSBox configuration

The recipe uses `dosbox.conf` as a template and `launch.sh` writes an absolute runtime config to:

```text
local/runtime/galactic-warrior-rats/galactic-warrior-rats.conf
```

Tested settings:

- `machine = svga_s3`
- `memsize = 16`
- `cpu_cycles = 6000`
- Sound Blaster 16 defaults: `A220 I7 D1 H5 T6`
- `mixer rate = 48000`, `blocksize = 1024`, `prebuffer = 80`
- `mididevice = none`
- no CD-ROM mount and no special mount flags; the extracted floppy root is mounted as `C:`

The game itself reported keyboard-only controls available, VGA 256-colour graphics, sound effects on and music on.

## Verification performed

Commands run successfully:

```sh
bash -n games/galactic-warrior-rats/install.sh games/galactic-warrior-rats/launch.sh
./games/galactic-warrior-rats/install.sh --existing --no-launch
GWR_DRY_RUN=1 ./games/galactic-warrior-rats/launch.sh
timeout 15s ./games/galactic-warrior-rats/launch.sh
```

The bounded launch test timed out with DOSBox still running, after loading the generated config, mounting the runtime game directory, initializing SB16/OPL and entering VGA modes.

For visual verification I also ran the official DOSBox-Staging 0.82.2 Linux runtime under X11 so screenshots and synthetic keyboard input could be captured. Verified screens:

- system/options screen: keyboard control, VGA 256-colour graphics, sound effects/music on
- title/programming/graphics credits
- hangar/shop interface with credits, energy/coolant bars, rat in biosphere vehicle and bottom menu
- keyboard navigation in the hangar menu
- `X` activates the `BUY` menu and shows the `AUTO SHOTGUN` item costing `CR 0100`

The user visually confirmed this looked like the game working as expected. I did not independently capture a first side-scrolling level screenshot before handoff, so the remaining conservative note is that a full first-level playthrough should still be recorded if stricter proof is needed.

## AppImage status

Assessed but not implemented in this pass. This DOS game should be packageable with the same DOSBox-Staging AppImage pattern used by `games/det-magiske-jordbaer/extras/build_appimage.sh`: bundle the extracted runtime game directory plus the official DOSBox-Staging x86_64 runtime, generate AppRun/desktop/icon metadata, then verify the bundled DOSBox log.

No blocker was found for AppImage packaging beyond time/scope; the next step is to create `extras/build_appimage.sh` from the Det Magiske Jordbær DOSBox pattern and smoke-test the AppDir/AppImage.

## Reference link

```text
https://archive.org/download/003318-GalacticWarriorRats/003318_galactic_warrior_rats.7z
```

Verify legal status in your country and only use copies you have the right to use.
