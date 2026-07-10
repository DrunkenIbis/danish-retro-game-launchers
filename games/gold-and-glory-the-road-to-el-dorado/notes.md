# Gold and Glory: The Road to El Dorado - implementation notes

## Media inspection

Source tested:

```text
https://archive.org/download/edc2000/ED_CD.iso
local/sources/gold-and-glory-the-road-to-el-dorado/ED_CD.iso
```

Observed with `file`:

```text
ISO 9660 CD-ROM filesystem data 'ED_CD'
```

Important ISO paths:

```text
autorun.inf
setup.exe
Setup2.exe
DirectX7/dxsetup.exe
engine/eldorado.ini
engine/linc/engine.exe
engine/linc/binkw32.dll
engine/linc/gfxlib.dll
engine/linc/readme.txt
g/music.clu
g/samples.clu
g/speech.clu
gmovies/*.bik
movies/*.bik
```

`autorun.inf`:

```ini
[AutoRun]
open=setup.exe
icon=engine\linc\engine.exe,0
```

Executable types:

```text
setup.exe:              PE32 GUI executable
Setup2.exe:             PE32 GUI executable
engine/linc/engine.exe: PE32 GUI executable
engine/linc/binkw32.dll: PE32 DLL
engine/linc/gfxlib.dll:  PE32 DLL
```

`setup2.exe` strings reveal the installed target and registry family:

```text
Typical Setup
Compact Setup
Silent Setup
engine
eldorado.ini
%CDROMDrive%\engine
%TargetDir%\engine\linc\engine.exe
Software\RevolutionSoftware\ElDorado
```

The game config is `engine/eldorado.ini`; save-game strings in `engine.exe` refer to `saves\EDgame*.index` and `saves\EDgame*.thumb` under the engine/linc tree.

## Tested Wine paths

### Direct CD-root engine launch

Test shape:

```sh
wine32 cmd /c 'cd /d D:\engine\linc && engine.exe'
```

Evidence:

```text
Window: El Dorado (C)2000 Revolution Software Ltd
WM_CLASS: engine.exe, engine.exe
Process: engine.exe
```

This proves the recipe found the actual game executable, not just setup/autostart. It does not prove gameplay.

### Wine Explorer virtual desktop

Test shape:

```sh
wine32 explorer /desktop=GoldGlory,800x600 'D:\engine\linc\engine.exe'
```

Observed blocker:

```text
X Error of failed request: BadWindow (invalid Window parameter)
Major opcode of failed request: 10 (X_UnmapWindow)
```

Because of this host-specific Wine/X11 failure, the recipe defaults `GGED_VIRTUAL_DESKTOP=0` and launches with `wine cmd /c`.

### Manual installed-copy mode

A manual `C:\ElDorado` tree was built by copying the CD `engine/` folder into the Wine prefix and registering:

```text
HKCU\Software\RevolutionSoftware\ElDorado Path=C:\ElDorado
```

Test shape:

```sh
wine32 cmd /c 'cd /d C:\ElDorado\engine\linc && engine.exe'
```

Observed blocker/user-visible Wine debugger output:

```text
Couldn't get first exception for process 00a4 C:\ElDorado\engine\linc\engine.exe.
No backtrace available
Exception c0000005
Wine build: wine-11.0 (Staging)
Platform: i386
Version: Windows 98
```

This is a hard blocker before gameplay. Do not call the game working from process/window existence.

## CD-check static analysis

Ghidra MCP was not reachable in this session (`127.0.0.1:8080` refused connection), so the CD-check was traced with PE imports, string xrefs, and `objdump` disassembly instead.

Relevant SHA256 for the analyzed private runtime executable:

```text
ca249989676f8c5e40abd708d3a7ac13e1b7708adbcc19af28512cfe9ef714d0  engine.exe
```

Important functions/addresses observed in the PE32 image:

```text
0x40ecd0  ClusterManager::InterrogateDrives-like routine
0x40eee0  ClusterManager::CheckForCD-like routine
0x40f310  missing-disc UI routine using opt_missingdisc
```

The CD detection logic appears to be straightforward Windows API media detection, not a low-level driver protection:

1. `GetLogicalDriveStringsA(0x80, buffer)` enumerates logical drives.
2. For each drive string, `GetDriveTypeA(root)` is called.
3. The first drive with return value `5` (`DRIVE_CDROM`) is copied into the cluster manager object.
4. If a second CD-ROM drive exists, it can also be copied into a secondary slot (`object+4`, guarded by `object+8`).
5. `GetDiskFreeSpaceA` is used separately for mission-install/free-space bookkeeping.
6. `CheckForCD(1)` uses hardcoded string `ED_CD`.
7. `GetVolumeInformationA(driveRoot, volumeNameBuffer, 0x80, ...)` reads the CD volume label.
8. The label is compared byte-for-byte against `ED_CD`; on match it sets a success/status field (`object+0x0c = 1`) and returns success.
9. `CheckForCD(2)` compares against the secondary CD drive label if a second disc/drive slot exists.
10. Unknown CD numbers log `ClusterManager::CheckForCD(# %d) unknown CD number to find!`.
11. If the check fails at runtime, the game has a missing-disc UI path using `opt_missingdisc`, `opt_quit`, `opt_back`, and `opt_exitgame`.

Wine verification in the recipe prefix showed the mapped drive already satisfies the visible label/path requirements:

```text
Volume in drive d is ED_CD
Directory of d:\ contains _ed_cd
Directory of d:\engine\linc contains engine.exe
```

Conclusion: the current repo launcher likely gets past the simple CD label/path check when Wine reports `D:` as `ED_CD`. The observed `c0000005` Wine debugger crash is therefore more likely DirectDraw/Direct3D 7, Bink/DirectSound, ICB runtime, or mission-install/path handling than an obvious missing CD label. A stricter next CD-emulation test would be a loop/physical CD mapping with `dosdevices/d::` pointing at the block device, but static analysis did not show SafeDisc/SecDrv-style driver access in this executable.

## Current hypothesis

The remaining failure may be one or more of:

- Wine 11 staging regression or DirectDraw/Direct3D 7 compatibility issue.
- ICB engine rendering/runtime incompatibility; this game is known to have invisible 3D model problems on newer Windows versions.
- Bink/DirectSound interaction during intro/movie startup.
- Installed vs CD-root context differences in where `engine/eldorado.ini`, Bink files, and mission cluster data are resolved.
- Less likely but still possible: Wine CD-ROM drive-type semantics beyond the visible `vol d:`/label checks.

## Next debugging steps

1. **Install Wine-GE 9.11.4** (LTS version with DirectDraw/Direct3D fixes):
   ```bash
   cd "$GGED_RUNTIME_DIR" && \
     export RETRO_GAME_WINEGE_DIR="$REPO_ROOT/local/winege" && \
     ./install-winege.sh --download  # Or --existing/--cd for physical media
   ```

2. **Run via Wine-GE launcher** (bypasses Staging DirectDraw bugs):
   ```bash
   cd "$GGED_RUNTIME_DIR/installed" && \
     export GGED_WINE="winege64" WINEARCH=win32 && \
     ./launch.sh
   ```

3. **Wine-GE environment** (automatically sets up with Windows 98 compatibility):
   - `WINEDLLOVERRIDES="mscoree=n,d;vcruntime=d"` — disable MS core/VC runtime checks
   - `WINEDEBUG="+seh,+ddraw,+d3d,+file,+mscoree"` — debug filter for ICB/DirectDraw rendering
   - `WINEARCH=win32` — 32-bit compatibility for engine.exe (Win98 NE executables)

4. **No-CD simulation** (optional workaround for CD-check bypass):
   ```bash
   export GGED_NO_CD=1 ./launch.sh
   # Simulates ED_CD volume label via virtual drive mapping, avoiding GetVolumeInformationA check
   ```

5. Test with debug logging: `GGED_WINEDEBUG="+seh,+ddraw,+d3d,+file,+mscoree" ./launch.sh`

6. If intro/movie hangs before gameplay, skip Bink files temporarily in ignored runtime.

7. Only after gameplay is verified (no c0000005 crash), implement AppImage packaging.

## AppImage decision

AppImage was deliberately not implemented. The launcher is not gameplay-verified, and installed mode currently crashes with `c0000005`. Packaging this now would create a misleading AppImage that can only reproduce a blocked state.

## 2026-07-10: verified CD-ROM media fix

The prior conclusion that the extracted `D:` mapping passed the CD check was wrong. It only passed Wine's `vol d:` check; the actual game showed `Please insert El Dorado CD`.

Using the original ISO as a loop-backed Wine CD-ROM passes that dialog:

- `udisksctl loop-setup` creates `/dev/loopN`; `udisksctl mount` provides the ISO mountpoint.
- Wine `D:` maps to that mountpoint, Wine `D::` maps to `/dev/loopN`, and `HKCU\\Software\\Wine\\Drives d:` remains `cdrom`.
- The game reached the Light & Shadow Production splash screen. This is not menu/gameplay verification.

`launch.sh` now defaults to `GGED_CD_BACKEND=loop`; `GGED_CD_BACKEND=extract` preserves the failing extracted-directory mapping as a diagnostic alternative. A bounded SIGTERM test verified the launcher removes the mount/loop device and `d::`, then restores `d:` to the extracted runtime directory.

## 2026-07-10: Wine-GE windowed working path

The system Wine 11 Staging runner only produced a fullscreen DirectDraw mode, and its Wine Explorer desktop was unusable on this host. Lutris exposed Wine-GE 8-26 as the most plausible alternate runner. It was installed privately under ignored `local/runners/` and uses ignored `wine-ge-prefix/` state.

The verified launcher defaults are Wine-GE plus `GGED_VIRTUAL_DESKTOP=1`, `GGED_DESKTOP_SIZE=640x480`, and centering of `GoldGlory - Wine desktop`. Wine-GE needs a readable `D::`: mapping it to `/dev/loopN` produces `Read access denied ... FS volume label and serial are not available`, so the launcher maps `D::` to the original readable ISO file while keeping `D:` mapped to the loop-mounted disc. The user confirmed this path now works as intended.

Wine Explorer can return before the game exits; `launch.sh` therefore waits for the selected runner's `wineserver -w` before cleanup, so the ISO is not unmounted while `engine.exe` is still running. The lock also records the wrapper PID so `GGED_MODE=kill` can recover from a Ctrl-Z-suspended launcher.
