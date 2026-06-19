# Notes: Magnus & Myggen På Skattesjov

## Disc inspection

Downloaded from:

```text
https://archive.org/download/magnus-myggen-paa-skattesjov/SS12DK.bin
https://archive.org/download/magnus-myggen-paa-skattesjov/SS12DK.cue
```

Hashes observed locally:

```text
0876120b6bbf90d5885499a57a5e43856c8e2ae359eb5094bd056678233f9951  SS12DK.cue
8f3182a528cc5b9946e97f9bfc5456e7e55a3d986d7b63dbc28222c90bded561  SS12DK.bin
```

CUE:

```text
FILE "SS12DK.bin" BINARY
  TRACK 01 MODE2/2352
    INDEX 01 00:00:00
```

The raw BIN is a single MODE2/2352 data track. Converting sector payload bytes 24..2071 to an ISO produced:

```text
sectors: 32450
ISO size: 66457600
file: ISO 9660 CD-ROM filesystem data 'SS12DK'
Volume id: SS12DK
```

Observed CD root after conversion/extraction:

```text
AUTORUN.INF
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

`AUTORUN.INF`:

```ini
[autorun]
open=launcher.exe
icon=mm.ico
```

Executable types:

- `LAUNCHER.EXE`: PE32 Windows GUI executable
- `MMSUPER.EXE`: PE32 Windows GUI executable
- `SETUP.EXE`: PE32 Windows GUI executable
- `Files_All_DK/mm8main.exe` from `DATA1.CAB`: PE32 Windows GUI executable, Macromedia Director MX 2004 projector

## Manual extraction

`unshield l DATA1.CAB` shows the useful game files:

```text
Files All DK\mydlg.cxt
Files All DK\mm8.HLP
Files All DK\mm8main.exe
Files All\Xtras\budapi.x32
Files All\Xtras\DirectSound.x32
Files All\Xtras\FileIo.x32
Files All\Xtras\Flash Asset.x32
Files All\Xtras\Font Asset.x32
Files All\Xtras\Font Xtra.x32
Files All\Xtras\iisys.x32
Files All\Xtras\lhWinSys.x32
Files All\Xtras\MacroMix.x32
Files All\Xtras\Mui Dialog.x32
Files All\Xtras\Regread.x32
Files All\Xtras\Sound Control.x32
Files All\Xtras\Text Asset.x32
Files All\Xtras\TextXtra.x32
```

The launcher copies these into a writable runtime `installed/` tree and mirrors them into `C:\Skattesjov` in the Wine prefix.

## Launch verification and blocker evidence

Direct `mm8main.exe` launch with a win32/win98 Wine prefix starts the Director projector. A bounded smoke test showed:

```text
WM_NAME(STRING) = "Magnus og Myggen - Skattesjov"
WM_CLASS(STRING) = "mm8main.exe", "mm8main.exe"

WM_NAME(STRING) = "Besked fra IVANOFF Interactive"
WM_CLASS(STRING) = "mm8main.exe", "mm8main.exe"
```

Wine `+file,+reg` logs showed:

```text
CreateFileW L"C:\\Skattesjov\\mydlg.cxt" ... returning handle
NtOpenKeyEx L"SOFTWARE\\Ivanoff interactive\\mm8"
RegQueryValueExA "appmanfile"
```

Relevant strings inside `mm8main.exe` include:

```text
gRegistered
gMinutes
used_minutes
SOFTWARE\Ivanoff interactive\mm8
Antallet af minutter tilbage er ugyldigt
Tiden på dit prøvespil er udløbet.
Du har nu følgende muligheder:
1. Luk dette vindue og prøv et andet Magnus og Myggen spil.
2. Køb spillet ved at klikke på [Køb spil] i SuperStarteren
Besked fra IVANOFF Interactive
```

Tested compatibility steps:

- Converted BIN/CUE to ISO and extracted the CD successfully.
- Bypassed InstallShield by extracting the actual Director app from `DATA1.CAB`.
- Launched from a writable `C:\Skattesjov` path rather than a host path.
- Added InstallShield-like registry values under `HKLM\Software\IVANOFF Interactive\MM8`: `AppPath`, `Language`, `netgame`.
- Added `HKLM\Software\IVANOFF Interactive\superstarter SourcePath`.
- Set Wine Windows version to `win98`.
- Mapped the extracted CD as Wine drive `D:` with label `SS12DK`.

Conclusion: compatibility is good enough to start the projector and load its resources, but the tested media is gated by SuperStarter/trial state. Bypassing that would be licence/trial circumvention, so this recipe documents the blocker rather than patching or forging unlock state.

## Original CD launcher/SuperStarter checks

`MMSUPER.EXE` also sees the installed MM8 registry key and repeatedly probes other `Software\IVANOFF Interactive\MM*` product keys. In the tested environment it did not produce a normal playable launch state before timeout.
