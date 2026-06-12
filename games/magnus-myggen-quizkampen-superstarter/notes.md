# Notes: Magnus & Myggen Quizkampen Superstarter

## Disc inspection

Downloaded from:

```text
https://archive.org/download/magnus-myggen-quizkampen-superstarter-version/Quizkampen%20Superstarter%20Version.iso
```

Observed with `file`:

```text
ISO 9660 CD-ROM filesystem data 'Q122DK'
```

Observed root files:

```text
AUTORUN.INF
DATA1.CAB
DATA1.HDR
DATA2.CAB
IKERNEL.EX_
LAUNCHER.EXE
LAYOUT.BIN
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
- `Application_DK/mm12main.exe` from `DATA1.CAB`: PE32 Windows GUI executable, Macromedia Director MX 2004 projector

## Manual extraction

`unshield l DATA1.CAB` shows the useful game files:

```text
Application DK\mm12main.exe
Application DK\qdata.cxt
Application DK\standard.cxt
Application DK\locmem.cxt
Application DK\mm12dk.HLP
Application\xtras\*.x32
```

The launcher copies those into a writable runtime `installed/` tree and starts `mm12main.exe` from that directory so Director can find the `.cxt` files and `xtras/` folder.

## Launch verification evidence

A bounded direct Wine test started the actual game process and exposed X11 windows:

```text
/home/test/danish-retro-game-launchers/local/runtime/magnus-myggen-quizkampen-superstarter/manual-install-test/mm12main.exe
WM_NAME(STRING) = "Quizkampen"
WM_CLASS(STRING) = "mm12main.exe", "mm12main.exe"
```

The bounded test exited with code 124 only because `timeout` stopped a still-running game. This is treated as smoke-test success because the target process and window were present.
