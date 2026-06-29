# Notes

## Intake

Requested slug: `galactic-warrior-rats`  
Source: `https://archive.org/download/003318-GalacticWarriorRats/003318_galactic_warrior_rats.7z`  
Media type: 7z archive containing an MS-DOS 1.44 MB floppy image.

Metadata supplied by user:

- Developer: Mikev Design
- Publisher: Summit Software
- Year: 1993 MS-DOS version
- Language: English
- Platform: MS-DOS
- Genre: Platformer
- Players: Single-player

## Archive inspection

Downloaded archive:

```text
local/sources/galactic-warrior-rats/003318_galactic_warrior_rats.7z
sha256: 44e67d11a9b7cd76f5553b3cbe6d618f64108cee05b0e26114632ad1e11ce4d1
```

`7z l -slt` showed exactly one payload image:

```text
003318_galactic_warrior_rats/disk1.img
```

`file disk1.img` identified a DOS FAT12 1.44 MB floppy image with volume label `GWR`.

The floppy image contains:

- `GWR.EXE` — MS-DOS MZ executable, PKLITE-packed payload
- `GWR.COM` — DOS launcher/stub
- level/resource files: `LEVSP.BIN`, `ALSP1.BIN`, `ALSP2.BIN`, `LEV1A`..`LEV6B`, `PATS1`..`PATS6`
- sample/audio files: `GAMEON.PCM`, `GAMEOVER.PCM`, `GWINGAME.PCM`, `GWRTITLE.PCM`

No installer/setup tool was present: no `INSTALL.EXE`, `SETUP.EXE` or `.BAT` file.

## Launcher decision

Use `GWR.COM`, not `GWR.EXE`, as the canonical launcher.

Evidence:

```text
strings GWR.COM:
GWR.EXE
Cannot find file GWR.EXE
Not enough memory to run programme -
error code
```

`GWR.EXE` is packed (`file` reports `Self-extracting PKZIP archive`/PKLITE). Running both candidates in DOSBox reached game modes, but `GWR.COM` is the wrapper that explicitly loads and validates `GWR.EXE`.

## DOSBox settings

Working/default recipe settings:

- `machine = svga_s3`
- `memsize = 16`
- `cpu_cycles = 6000`
- `sbtype = sb16`, `sbbase = 220`, `irq = 7`, `dma = 1`, `hdma = 5`
- `mididevice = none`
- `mount c <runtime game dir>` only; no CD-ROM mount required

Initial game screen itself reported:

```text
Keyboard control only
256 colour VGA graphics only
Sound Effects On
Music On
```

No separate sound setup utility was present, so SB16 defaults are used. The `.PCM` sample files and successful DOSBox SB16/OPL initialization are the best available evidence for audio path readiness without a longer audio-specific play session.

## Verification log

2026-06-29:

- `bash -n games/galactic-warrior-rats/install.sh games/galactic-warrior-rats/launch.sh` passed.
- `./games/galactic-warrior-rats/install.sh --existing --no-launch` validated the SHA256, verified `disk1.img`, extracted the source/cache and extracted runtime game files.
- `GWR_DRY_RUN=1 ./games/galactic-warrior-rats/launch.sh` printed the expected source/runtime/config paths.
- `timeout 15s ./games/galactic-warrior-rats/launch.sh` loaded DOSBox-Staging Flatpak 0.82.2, mounted runtime `game/`, initialized SB16/OPL and entered VGA modes. Exit code 124 was expected from the bounded timeout while the game was still running.
- For screenshots and keyboard injection, downloaded official DOSBox-Staging 0.82.2 Linux runtime to ignored runtime cache and ran it with `SDL_VIDEODRIVER=x11`.
- Captured screenshots of intro/options screen, title/programming credits, hangar/shop screen and `BUY` submenu (`AUTO SHOTGUN`, `CR 0100`).
- User visually confirmed the observed state looked like the game working as expected.

Conservative gap: I did not capture a first side-scrolling level screenshot before stopping. If future work requires stricter proof, continue from the hangar/shop UI and document the exact key sequence from the hangar into the first level.

## Controls discovered during smoke test

- Space advances the initial options/title screens.
- Left/right arrow keys move the hangar bottom-menu cursor.
- `X` activates the selected menu item; on `BUY`, it opens the buy panel.
- `Esc` exits the game/DOSBox cleanly.

## AppImage assessment

No AppImage script was added in this pass. The game is a good candidate for the existing DOSBox AppImage pattern:

1. Run `./install.sh --download --no-launch` or `--existing --no-launch`.
2. Copy `local/runtime/galactic-warrior-rats/game/` into an AppDir.
3. Bundle official DOSBox-Staging Linux x86_64 runtime.
4. Generate an AppRun that runs bundled DOSBox with this recipe's generated config.
5. Verify AppDir metadata, icon files and bundled DOSBox launch logs.

Reusable learning: for small DOS floppy-image archives, treat the outer 7z and inner floppy image as separate validation/extraction phases; inspect the floppy for setup tools before choosing a launcher.
