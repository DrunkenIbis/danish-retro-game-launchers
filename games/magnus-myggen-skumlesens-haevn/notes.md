# Notes: Magnus & Myggen Skumlesens Hævn

## Disc inspection

Downloaded from:

```text
https://archive.org/download/magnus-myggen-skumlesens-haevn/M322DK.bin
https://archive.org/download/magnus-myggen-skumlesens-haevn/M322DK.cue
```

Hashes observed locally:

```text
1d27ec277b6f86db495b84ac466ee0d74857f5e23eb73cdf02d2ddcd1963cbad  M322DK.cue
554a0254eb9992cb528ec6fb249f61d9f6e9995074e67e547c64461dee23f4ff  M322DK.bin
```

CUE:

```text
FILE "M322DK.bin" BINARY
  TRACK 01 MODE1/2352
    INDEX 01 00:00:00
```

The raw BIN is a single MODE1/2352 data track. Converting sector payload bytes 16..2063 to ISO produced:

```text
sectors: 145870
ISO size: 298741760
file: ISO 9660 CD-ROM filesystem data 'M322DK'
Volume id: M322DK
```

Observed CD root essentials after conversion/extraction:

```text
AUTORUN.INF
DATA1.CAB
DATA1.HDR
DATA2.CAB
DIRECTX/
LAUNCHER.EXE
MM.ICO
SETUP.EXE
SETUP.INI
SETUP.INX
```

`AUTORUN.INF`:

```ini
[autorun]
open=launcher.exe
icon=mm.ico
```

Executable types:

- `LAUNCHER.EXE`: PE32 Windows GUI executable
- `SETUP.EXE`: PE32 Windows GUI executable
- `appfiles/mm3run.exe` from `DATA1.CAB`/`DATA2.CAB`: PE32 Windows GUI executable

`LAUNCHER.EXE` strings show it probes `Software\IVANOFF InterActive\MM3` `AppPath` and can start `mmsuper.exe` or `Setup.exe`.

## Manual extraction

`unshield l DATA1.CAB` depends on `DATA2.CAB` being beside `DATA1.CAB`; otherwise extraction of the large resources fails.

Useful payload:

```text
appfiles/UI.ICO
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
music/music/BG_*.DAT
music/music/FG_*.DAT
music/music/CREDIT_W.DAT
superstarter_DK/mmsuper.exe
_Support_Non-SelfRegistering/default.pal
_Support_Non-SelfRegistering/isrt.dll
```

The launcher copies:

- `appfiles/*` and `appfiles_DK/*` to the install root,
- Danish `resfiles_DK/DK/*.DAT` to `DK/`,
- `music/music/*.DAT` to `music/`,
- support `default.pal` and `isrt.dll` beside `mm3run.exe`.

It then mirrors the install tree into `C:\Program Files\Magnus & Myggen - Skumlesens Haevn` inside a win32 Wine prefix and sets these registry values:

```text
HKLM\Software\IVANOFF Interactive\MM3 AppPath      = C:\Program Files\Magnus & Myggen - Skumlesens Haevn
HKLM\Software\IVANOFF Interactive\MM3 MusicPath    = C:\Program Files\Magnus & Myggen - Skumlesens Haevn\music
HKLM\Software\IVANOFF Interactive\MM3 UseFullScreen = 0
HKLM\Software\IVANOFF Interactive\Superstarter AppPath = C:\Program Files\Magnus & Myggen - Skumlesens Haevn
```

## Launch verification and blocker evidence

Concrete test performed from the repo-local runtime:

1. `install.sh --existing --no-launch` validated the converted `M322DK.iso`.
2. `MM3_MODE=prepare ./launch.sh` extracted the CD, manually unpacked InstallShield CABs, initialized the Wine prefix, copied the runtime into `C:\Program Files\...`, and wrote registry values.
3. A bounded `./launch.sh` run started `mm3run.exe` in an `MM3 - Wine Desktop` 800x600 window.
4. Screenshot of the Wine desktop showed the modal `This trial game has expired.`.

Process/window evidence from the manual debug run before codifying the recipe:

```text
WM_NAME(STRING) = "MM3 - Wine Desktop"
WM_CLASS(STRING) = "explorer.exe", "explorer.exe"

C:\Program Files\Magnus & Myggen - Skumlesens Haevn\mm3run.exe
```

Visible blocker:

```text
This trial game has expired.
```

Relevant `mm3run.exe` strings:

```text
Your screen has to be in 16 bit colors
This trial game has expired.
Software\IVANOFF Interactive\MM3
MusicVolume
MusicPath
UseFullScreen
Resource file error
Savegame%02d.mm3
settings.dat
```

Conclusion: Wine compatibility is sufficient to start the game executable and display its own UI, but the tested media/state is a trial-expired build or SuperStarter-gated state. Bypassing that would be licence/trial circumvention, so this recipe documents the blocker instead of patching or forging state.

## Tested alternatives / notes

- `AUTORUN.INF` points to `LAUNCHER.EXE`, but the recipe avoids relying on the launcher because the actual runtime is inside the InstallShield CABs.
- `SETUP.EXE` is PE32 InstallShield, not a Win16 installer. Manual CAB extraction is deterministic and avoids old installer/UI issues.
- `unshield` on this machine requires `LD_LIBRARY_PATH=/home/test/.local/pkg/unshield-rpm/usr/lib64` when using `/home/test/.local/bin/unshield`; the wrapper handles that fallback.
- The game contains a `Your screen has to be in 16 bit colors` string. This was not the observed blocker; the observed blocker was the trial-expired modal.
- Bounded follow-up tests used 12-20 second observation windows plus forced `wineserver -k` cleanup to avoid waiting indefinitely:
  - `MM3_MODE=game` still starts `mm3run.exe` and shows `This trial game has expired.`
  - `MM3_MODE=launcher` starts `D:\LAUNCHER.EXE` but produced no visible launcher UI in the bounded window.
  - `MM3_MODE=setup` starts `D:\SETUP.EXE` but produced no visible installer UI in the bounded window.
- `MM3_MODE=superstarter` is intentionally disabled after user clarification: SuperStarter is a shop/trial frontend, not the game executable. It must not be used as a compatibility path for gameplay verification.
- These tests did not find a false-expiry compatibility cause. The shipped SuperStarter help text explicitly describes trial games, expired minutes, and paid registration codes, which supports treating this media/state as a trial-gated distribution, but the launcher recipe should target `mm3run.exe` directly.
- AppImage packaging was not added because the direct wrapper is known-blocked before gameplay. Revisit AppImage after lawful media/state reaches gameplay through `launch.sh`.
