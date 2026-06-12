# Notes: Magnus & Myggen Den Store Skattejagt

## Previous local attempt

There was already a migrated attempt from:

```text
/home/test/lutris_game_scripts_mm2
```

That attempt contained the important compatibility clues, but the recipe still had hardcoded old paths and expected private media/runtime folders beside the recipe. This pass reworked the recipe into the repo pipeline style:

- private media under `local/sources/magnus-myggen-den-store-skattejagt/`,
- runtime/extracted data under `local/runtime/magnus-myggen-den-store-skattejagt/`,
- `install.sh` for interactive/non-interactive source acquisition,
- `launch.sh` as the canonical wrapper,
- no BIN/CUE/ISO/extracted CD/Wine prefix in Git.

## Disc inspection

Source URLs:

```text
https://archive.org/download/magnus-myggen-den-store-skattejagt/MM2NORD.bin
https://archive.org/download/magnus-myggen-den-store-skattejagt/MM2NORD.cue
```

Observed hashes:

```text
f5691999c0fabac829c6774cc5568a9e7d9b35212b4aac609d1c22e26e6c8b50  MM2NORD.cue
7ee9eb858b1acbf0cbc350e889a0f35d8e6807c62b93bf01744302d31a84329d  MM2NORD.bin
e5fec65947e115b07742be36646c5ad15c745fb6e798ec55d18bd2f13d7c4e91  MM2NORD.iso
```

CUE:

```text
FILE "MM2NORD.bin" BINARY
  TRACK 01 MODE1/2352
    INDEX 01 00:00:00
```

The BIN converts to ISO by copying bytes 16..2063 from each 2352-byte MODE1 sector.

Converted ISO evidence:

```text
ISO 9660 CD-ROM filesystem data 'MM2NORD'
Volume id: MM2NORD
Volume size: 289919 logical blocks
```

Important CD root files:

```text
AUTORUN.INF
DATA1.CAB
DATA1.HDR
DATA2.CAB
DK/MM2LNG.DAT
DK/MM2LNG.IDX
LAUNCHER.EXE
MM2.DAT
MM2.IDX
SETUP.EXE
```

`AUTORUN.INF`:

```ini
[autorun]
open=launcher.exe
icon=mm2.ico
```

Executable types:

- `LAUNCHER.EXE`: PE32 Windows GUI executable
- `SETUP.EXE`: PE32 Windows GUI executable
- `Program_files_DK/mm2run.exe` from `DATA1.CAB`: PE32 Windows GUI executable

## Manual extraction

`unshield l DATA1.CAB` shows:

```text
Program files DK\mm2run.exe
Program files N\mm2run.exe
Program files SF\mm2run.exe
Program files S\mm2run.exe
Program files\mkcapdir.exe
Program files\ii.ico
Program files\ui.ico
```

The recipe extracts the Danish executable only and keeps the large data files on the CD runtime directory.

## Registry/resource details

`DATA1.HDR` contains the InstallShield registry/resource shape:

```text
Software\IVANOFF Interactive\mm2
Resource file       <SRCDIR>\mm2
Resource local file <RESLNGSRCDIR>\mm2lng
ProgramPath
Language
PRODUCT_LANGUAGE
```

The wrapper writes equivalent values under `HKLM\Software\IVANOFF Interactive\MM2`:

```text
mm2lng=DK
Resource file=D:\MM2
Resource local file=D:\DK\MM2LNG
SoundLevel=100
BkgMusicOn=1
WWWLinksOff=1
```

Use base resource names without `.DAT`/`.IDX`; the game appends extensions itself.

## Compatibility notes

Observed/kept from the previous debug folder and current verification:

- Use `wine32` and a 32-bit prefix.
- Set Wine Windows version to `win98`; Wine's Windows 10 default can crash this Win95/98-era program early.
- Do not pre-create `settings.dat`; an existing initialized settings file in the old debug prefix was evidence from a previous run, but pre-creating it manually can cause an access violation.
- The wrapper creates only the containing `C:\ProgramData\IVANOFF\MM2\2.0` directory before launch.
- Avoid Wine Explorer virtual desktop by default. The old attempt noted that Explorer desktop could trigger X11 `BadWindow`/debugger behaviour for this title. Direct launch is the default; virtual desktop remains available with `MM2_VIRTUAL_DESKTOP=1`.
- A lock file is used so stale WineDbg sessions or overlapping wrappers do not collide.

## Verification evidence

The recipe has been tested from the repo copy, not just from `/home/test/lutris_game_scripts_mm2`.

Prepare checks performed:

```text
install.sh --existing --no-launch: converted/validated ISO
MM2_MODE=prepare ./launch.sh: extracted CD, unshielded Program_files_DK/mm2run.exe, initialized wineprefix32, wrote registry
```

A bounded launch should show a real process/window, not just a timeout. During testing, check with:

```sh
pgrep -af 'MM2RUN|mm2run|wine'
xprop -root _NET_CLIENT_LIST
xprop -id <window-id> WM_NAME WM_CLASS _NET_WM_PID
```

Verified launch evidence:

```text
MM2RUN.EXE process exists from local/runtime/magnus-myggen-den-store-skattejagt/installed-dk/MM2RUN.EXE
WM_NAME(STRING) = "IVANOFF Interactive"
WM_CLASS(STRING) = "mm2run.exe", "mm2run.exe"
_NET_WM_STATE(ATOM) = _NET_WM_STATE_FULLSCREEN
```

Wine `+file,+reg` evidence confirmed the important resource path is correct:

```text
RegQueryValueExA "Resource file"
RegQueryValueExA "Resource local file"
CreateFileW "D:\\MM2.DAT" returning handle
CreateFileW "D:\\DK\\MM2LNG.DAT" returning handle
CreateFileW "D:\\MM2.IDX" returning handle
CreateFileW "D:\\DK\\MM2LNG.IDX" returning handle
```

Visual verification with X11 screenshot/vision analysis still showed black content in the Wine desktop capture, but the window is no longer unmanaged/off-screen fullscreen. After enabling `MM2_VIRTUAL_DESKTOP=1` and the centering helper, current geometry evidence is:

```text
WM_NAME(STRING) = "MagnusMyggen2 - Wine Desktop"
WM_CLASS(STRING) = "explorer.exe", "explorer.exe"
MM2RUN.EXE process exists from local/runtime/magnus-myggen-den-store-skattejagt/installed-dk/MM2RUN.EXE
X11 geometry: 800x600 at root x=1520 y=277 on a 3840x1080 display
```

User-facing observation during live testing: the game appears to be running, and the prior symptom may have been an off-screen/fullscreen placement issue. Keep the recipe conservative: it launches centered, but do not mark fully playable from automated screenshot evidence alone until visible menu/gameplay is captured.

Current caveats / next direction:

- The launcher/media/registry path is correct enough to load all major resource files.
- The wrapper defaults to a centered 800x600 Wine virtual desktop (`MM2_VIRTUAL_DESKTOP=1`, `MM2_CENTER_WINDOW=1`) because direct fullscreen can appear black/off-screen on this setup.
- `MM2RUN.EXE` imports WinMM/MSVFW/GDI but not DirectDraw; if black visuals remain on another machine, investigate old fullscreen/GDI palette/display-mode compatibility.
- Do not mark this recipe fully playable until visible game graphics/menu are observed, not just the process/window/audio.

If the game later crashes into `winedbg --auto`, first stop Wine cleanly with:

```sh
MM2_MODE=kill ./launch.sh
```

Then retry direct mode (`MM2_VIRTUAL_DESKTOP=0`) before changing registry or CD mapping.
