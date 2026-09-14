# Gys på Regneslottet

Status: **working, user-confirmed on 2026-09-14**. The user confirmed that the
CPU/audio-stutter fix works very well and subsequently confirmed that the
AppImage test looked correct. Agent screenshots verify an actual arithmetic game scene in the final
AppImage with default user state, not a complete playthrough.

Runner: DOSBox-Staging 0.83 with the game's bundled Windows 3.11 installation.
This recipe contains no game media, Windows installation, emulator binary or
AppImage artifact. Private local builds contain those files; do not publish them
without the relevant redistribution rights.

## Install and run the recipe

Bring your own legally obtained `Gys_Paa_Regneslottet.zip`:

- Size: 62,693,702 bytes
- SHA-256: `0930e6961d89ac25638124812e0ad1637cb1cf97c0cc0229f937e5850461a0d2`
- Default source: `local/sources/gys-paa-regneslottet/Gys_Paa_Regneslottet.zip`

From the repository root:

```sh
./games/gys-paa-regneslottet/install.sh --archive /path/to/Gys_Paa_Regneslottet.zip --no-launch
./games/gys-paa-regneslottet/launch.sh
```

The launcher extracts to `local/runtime/gys-paa-regneslottet/`, repairs the
bundled Windows video/WinG profile and removes its unused network Program
Manager group. It starts:

```text
WIN C:\GILISOFT\GYS_CD\WNEWADDD.EXE /CFG:C:\GILISOFT\GYS_CD\WNEWADD.INI /startdir:D:\DANSK
```

C: is the writable Windows/game tree; D: is the original bundled CDROM.iso.
Host mounts use POSIX paths (`./GAME`, `./CDROM/CDROM.iso`); the old `.\GAME`
form failed with `Image file not found` on Staging 0.83.

## Audio and CPU fix

Current tested defaults:

- CPU: `core=normal`, `cputype=486`, `cpu_cycles=15000`
- `cpu_cycles_protected=auto` inherits this fixed cycle value, not max speed
- PulseAudio output; 44100 Hz, blocksize 2048, prebuffer 80
- Sound Blaster 2.0, A220 I7 D1, matching the bundled Windows sound driver
- ET4000 SVGA, 16 MB memory, 640×480 window
- Unused GUS, MIDI output, NE2000 and Voodoo disabled

The previous 50000-cycle setting used about 98% of one host CPU core. The
normal/15000 test used about 55–58%, leaving scheduling headroom. The audio
buffer and sample rate were not changed in this fix. The user confirmed the
result, rather than audio quality being inferred from logs alone.

Optional recipe overrides (close the previous game first):

```sh
GYS_CPU_CYCLES=20000 ./games/gys-paa-regneslottet/launch.sh
# Old CPU behavior for comparison only:
GYS_CPU_CORE=auto GYS_CPU_CYCLES=50000 ./games/gys-paa-regneslottet/launch.sh
```

## Build and run the AppImage

```sh
./games/gys-paa-regneslottet/extras/build_appimage.sh
# Rebuild from the already downloaded, checksum-verified tools:
./games/gys-paa-regneslottet/extras/build_appimage.sh --no-download
# Only prepare the unpacked application directory:
./games/gys-paa-regneslottet/extras/build_appimage.sh --appdir-only
```

Build dependencies: Python 3.12+, bash, unzip, wrestool (icoutils), ImageMagick
(`magick`) and internet access for the first tool download. `GYS_ARCHIVE`,
`GYS_ZIP`, `GYS_SOURCE_DIR` and `RETRO_GAME_SOURCE_DIR` can locate private media.
A clean private extraction is prepared through the canonical launcher, so the
AppImage inherits its verified configuration without copying your live saves.

Outputs:

```text
games/gys-paa-regneslottet/extras/dist/gys-paa-regneslottet-x86_64.AppImage
games/gys-paa-regneslottet/extras/dist/gys-paa-regneslottet-x86_64.AppImage.sha256
games/gys-paa-regneslottet/extras/build/gys-paa-regneslottet.AppDir
```

Run the AppImage directly or double-click it. It contains official DOSBox-Staging
0.83.0, resources/licenses, the clean prepared Windows/game tree, CD image and
the original game icon extracted from WNEWADDD.EXE. Downloads are SHA-256 pinned;
`build-provenance.json` records inputs and the canonical config checksum.

No Wine, Flatpak, system DOSBox or Python is needed at play time. This is a Linux
x86_64 bundle, not a guarantee for every distribution: host bash/coreutils/flock,
compatible glibc/libstdc++, audio and graphics drivers are still needed. The
upstream DOSBox runtime README and licenses are included. If FUSE is unavailable,
extract the AppImage with `--appimage-extract` and run `squashfs-root/AppRun`.

### Saved games and settings

The AppImage creates a separate writable installation at:

```text
${XDG_DATA_HOME:-$HOME/.local/share}/gys-paa-regneslottet/GAME/
```

Existing recipe saves are not automatically imported. The initial copy is atomic;
subsequent launches preserve it. The CD symlink is refreshed for each AppImage
mount, and a launch lock prevents concurrent use of the same state. Back up this
GAME directory before resetting it. Audio backend override:
`GYS_SDL_AUDIODRIVER=pulse`. For CPU experiments, pass DOSBox options such as
`--set cpu_cycles=20000` to the AppImage; the default remains 15000.

## Verification and limitations

- Recipe: user-confirmed improved gameplay/audio; screenshot verification to
  difficulty selection; generator regression tests and bash syntax checks pass.
- AppImage: fresh and default-user-state launches verified; the final default-state
  screenshot shows an arithmetic puzzle with two skeletons. Actual FUSE-launched process verified at `/tmp/.mount_*/runtime/dosbox`,
  with bundled resources and CD data, PulseAudio 44100 Hz and about 54% CPU in
  the sampled intro. User confirmed the running AppImage looked correct.
- Extracted finished package checked for matching desktop/icon files, bundled
  runtime/license, canonical config and provenance. Writable state preservation
  and CD remapping after moving an AppDir have an automated regression test.
- Closing the emulator window or forcibly stopping it can emit
  `Pagefault didn't correct page` during shutdown. This remains a shutdown
  compatibility issue, not evidence of a spontaneous gameplay crash.
- Staging 0.83 reports deprecations for legacy window/shader/IMGMOUNT settings.
  These are retained for compatibility with the canonical configuration.
- No full playthrough, other-distribution verification or independent listening
  verdict for the AppImage is claimed.

```sh
python3 games/gys-paa-regneslottet/extras/test_config.py
python3 games/gys-paa-regneslottet/extras/test_appimage.py
```

`lutris.yml` remains a local installer for the canonical recipe. The separate
`launch_wine95.sh` is an older experimental alternative, not the working default.
Historical troubleshooting and the original reference video are in `notes.md`.
