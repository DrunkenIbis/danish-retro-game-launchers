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
superstarter DK\mmsuper.exe
```

The launcher copies those into a writable runtime `installed/` tree and starts `mm12main.exe` from that directory so Director can find the `.cxt` files and `xtras/` folder.

## Launch verification and blocker evidence

The executable starts, but this Superstarter ISO is not a fully unlocked standalone game launch:

```text
/home/test/danish-retro-game-launchers/local/runtime/magnus-myggen-quizkampen-superstarter/installed/mm12main.exe
WM_NAME(STRING) = "Quizkampen"
WM_CLASS(STRING) = "mm12main.exe", "mm12main.exe"
WM_NAME(STRING) = "0"
WM_CLASS(STRING) = "mm12main.exe", "mm12main.exe"
```

The second `WM_NAME = "0"` window is the modal shown in the user's screenshot: IVANOFF splash background, small Magnus drawing, text area containing `0`, and an `Ok` button.

This was investigated with Wine `+file,+reg` logging:

- The Director projector opens `standard.cxt`, `qdata.cxt`, and `locmem.cxt` successfully.
- It enumerates and loads `xtras/*.x32` successfully, including `Mui Dialog.x32`, `FileIo.x32`, `TextXtra.x32`, etc.
- It then opens `HKLM\Software\IVANOFF Interactive\mm12` and queries `reg_message`, `reg_caption`, and `appmanfile` before showing the modal.
- Setting `reg_caption` changed the dialog title from `0` to `Information`, confirming the dialog is the game's own registry-driven `MyAlertHook` and not a Wine crash.
- SuperStarter (`mmsuper.exe`) displays the Quizkampen tile as `0 gratis minutter` with the button `Køb spil`; it does not present a normal playable/installed launch state for this title.

Tested hypotheses that did not pass the blocker:

- Running from host path and from `C:\Quizkampen`.
- Adding installer-like registry values from `DATA1.HDR`: `AppPath`, `Language`, `netgame`, `fullscreen`, `qsets`, `using`, `settingsdir`, display values.
- Mirroring values under HKLM/HKCU and `MM12`/`mm12` casing.
- Adding SuperStarter `appmanfile` and `appmansetting` variants.
- Using trailing backslash in `settingsdir` and pre-creating settings directories.

Conclusion: compatibility is good enough to start the projector and load its resources, but the shipped SuperStarter media is gated by SuperStarter/demo/licence state (`0 gratis minutter` / `Køb spil`). Bypassing that would be a licence/no-CD circumvention path, so this recipe documents the blocker rather than patching or forging unlock state.
