# Gys på Regneslottet

Status: repo-local pure DOSBox launcher smoke-verified with the game-bundled DOSBox config as base; needs final human listening/gameplay confirmation.
Runner: DOSBox-Staging running the bundled Windows 3.x game tree.

This directory contains only the compatibility recipe. It does not contain the game archive, extracted runtime, logs, screenshots, or AppImage output.

## Bring your own game files

Use a legally obtained copy of:

```text
Gys_Paa_Regneslottet.zip
sha256: 0930e6961d89ac25638124812e0ad1637cb1cf97c0cc0229f937e5850461a0d2
size:   62,693,702 bytes
```

Place it in:

```text
local/sources/gys-paa-regneslottet/Gys_Paa_Regneslottet.zip
```

or import it with `install.sh --archive`.

## Install/import

```sh
./games/gys-paa-regneslottet/install.sh --archive /path/to/Gys_Paa_Regneslottet.zip --no-launch
# or, after the archive is already in local/sources/gys-paa-regneslottet/
./games/gys-paa-regneslottet/install.sh --existing --no-launch
```

The installer writes only to ignored private paths:

```text
local/sources/gys-paa-regneslottet/
local/runtime/gys-paa-regneslottet/
```

## Run

```sh
./games/gys-paa-regneslottet/launch.sh
```

## Experimental Wine 95 launcher

There is also a separate experimental Wine path that does not replace the
canonical DOSBox launcher:

```sh
./games/gys-paa-regneslottet/launch_wine95.sh
```

It creates a private 32-bit Wine prefix under
`local/runtime/gys-paa-regneslottet/wine95/`, sets Wine's reported Windows
version to `win95`, extracts `CDROM.iso` to a mapped `D:` drive, copies the
preinstalled `GILISOFT\GYS_CD` tree to `C:`, and starts the Win16 launcher with:

```text
wine32 start /exec explorer /desktop=GysWine95,1024x768 C:\GILISOFT\GYS_CD\WNEWADDD.EXE /CFG:C:\GILISOFT\GYS_CD\WNEWADD.INI /startdir:D:\DANSK
```

Verification so far: a bounded smoke test shows `winevdm.exe` running with
`C:\GILISOFT\GYS_CD\WNEWADDD.EXE`. This is process/launcher evidence only;
visible gameplay and audio quality still need manual confirmation.

The launcher now uses the DOSBox config shipped with the game as its source:

```text
local/sources/gys-paa-regneslottet/Gys_Paa_Regneslottet/Gys På Regneslottet/SYSTEM/DOSBOX/dosbox.conf
```

At runtime it writes an ignored adapted copy to:

```text
local/runtime/gys-paa-regneslottet/gys-paa-regneslottet.conf
```

Only wrapper-safe changes are applied: 640x480 windowed startup, the repo-local
`[autoexec]` mount/start block, DOSBox-Staging-compatible memory/CPU values,
and a runtime Windows 3.1 video self-heal for the 256-colour Super VGA driver.

Useful tuning overrides:

```sh
GYS_CPU_CYCLES=35000 ./games/gys-paa-regneslottet/launch.sh
GYS_SDL_AUDIODRIVER=pipewire ./games/gys-paa-regneslottet/launch.sh
GYS_CPU_CYCLES=45000 GYS_MIXER_BLOCKSIZE=4096 GYS_MIXER_PREBUFFER=120 ./games/gys-paa-regneslottet/launch.sh
```

Default audio/timing currently intentionally follows the supplied YouTube/original-bundle reference more closely than the earlier PipeWire tuning. In the generated config these are inherited or adapted from the bundled config:

- `SDL_AUDIODRIVER=pulse`
- `machine=svga_et4000`
- `windowresolution=640x480`
- `memsize=16`
- `core=auto`
- `cputype=486`
- `cycles=50000` in the bundled-config copy, because the original `cycles=auto` made DOSBox-Staging switch to max cycles and the program exited quickly, while 40000 still sounded slightly slow for the user
- `rate=44100`
- `blocksize=2048`
- `prebuffer=80`
- Sound Blaster 2.0 (`sbtype=sb2`, `A220 I7 D1`) to match the bundled Windows `sndblst2.drv` / Creative Labs Sound Blaster 1.5 driver
- unused GUS, MIDI, NE2000, and Voodoo devices disabled to reduce emulation overhead

## Launcher evidence

The archive is a prebuilt Windows 3.x/DOSBox package. The wrapper launches the game directly inside the bundled Windows tree:

```text
win c:\gilisoft\gys_cd\wnewaddd.exe /CFG:c:\gilisoft\gys_cd\wnewadd.ini /startdir:d:\dansk
```

Runtime mounts:

```text
C: local/runtime/gys-paa-regneslottet/.../SYSTEM/DOSBOX/GAME
D: local/runtime/gys-paa-regneslottet/.../SYSTEM/DOSBOX/CDROM/CDROM.iso
```

`WNEWADDD.EXE` is a Windows 3.10 NE GUI executable. `CDROM.iso` contains `DANSK/ADD.A`, `DANSK/ADD.B`, `DANSK/ADD.LOD`, `DANSK/ADD.TXP`, setup files, and launch resources.

## Compatibility notes

- The bundled Windows Program Manager references an unused Danish network group (`NETVÆRK.GRP`). The launcher removes that Group3/Order reference and deletes stale mojibake filenames to avoid a Windows 3.x "Fejl i gruppefilen" prompt.
- The game requires Windows 3.1/95 VGA 256 colours. The launcher keeps the runtime Windows tree on `SVGA256.DRV` / `VDDSVGA.386` / `VGADIB.3GR`, sets the DOSBox window to 640x480, and seeds WinG's bundled-good `SVGA256.DRV640x480x8...=2` profile. This targets the WinG display-driver dialogs shown when WinG has a bad/stale profile.
- `unzip` can return status 1 because of a local/central filename mismatch for `NETV’RK.GRP`. The installer/launcher treats that as non-fatal only after the required game files are present.
- The first validation used 48 kHz/PipeWire settings and the user reported bad/stuttering audio. The current launcher switches to PulseAudio and 44.1 kHz settings matching the YouTube reference stream and original bundled DOSBox config more closely.
- After gameplay improved, the user still reported crackle and slightly slow audio. The current default retune uses larger 2048/80 audio buffering, 50000 cycles, and a simpler SB2 path instead of the default SB16/GUS/MIDI-heavy bundled profile.

## Verification performed 2026-06-30

Commands run:

```sh
bash -n games/gys-paa-regneslottet/install.sh games/gys-paa-regneslottet/launch.sh
./games/gys-paa-regneslottet/install.sh --existing --no-launch
GYS_DRY_RUN=1 ./games/gys-paa-regneslottet/launch.sh
timeout 25s ./games/gys-paa-regneslottet/launch.sh
python3 -c 'import yaml; yaml.safe_load(...)'
```

Observed evidence from the final smoke test:

- DOSBox-Staging 0.82.2 loaded the generated config derived from the bundled `dosbox.conf`.
- SDL initialized with Wayland video and PulseAudio audio.
- Mixer initialized at 44100 Hz with a 1024 sample frame buffer.
- `C:` mounted the runtime `GAME` tree.
- `D:` imgmounted `CDROM.iso`.
- CDAUDIO operated at 44100 Hz without resampling.
- The game entered SVGA 640x480 256-colour graphics mode 2Eh and stayed alive until the bounded timeout killed it.

Remaining gaps:

- Automated screenshot capture did not work in this Wayland session, so the agent did not independently capture a gameplay screenshot.
- The latest audio tuning still needs the user to listen and confirm it matches the YouTube reference.
- No AppImage script exists for this title yet. It is feasible to adapt the repo's DOSBox-Staging AppImage pattern after audio/gameplay is confirmed.

## Lutris

`lutris.yml` is a local installer script pointing at this repo-local `launch.sh`. The wrapper remains the canonical entry point.
