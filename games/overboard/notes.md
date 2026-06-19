# Overboard! / Shipwreckers! notes

## Media inspection

The Archive.org `OVERBOARD.zip` contains only:

```text
OVERBOARD.bin
OVERBOARD.cue
```

The CUE describes a mixed-mode CD:

```text
TRACK 01 MODE2/2352
TRACK 02+ AUDIO
```

The important trap is that the BIN is not a mountable ISO and should not be fed to `mkisofs`. `mkisofs` would create a new ISO containing the raw BIN as a file, which hides the real game files and wastes time.

The working conversion is:

1. unzip `OVERBOARD.bin` and `OVERBOARD.cue`
2. parse `TRACK 02 INDEX 00` from the CUE as the end of the data track
3. for each sector before that point, copy bytes `24..2071` from the 2352-byte MODE2 sector
4. patch ISO9660 PVD/SVD volume-space-size to the number of converted data sectors so `7z` validates without `Unexpected end of archive`

This produced a readable `OVERBOARD.iso` with:

```text
AUTORUN.INF
AUTORUN.EXE
OB.EXE
RES.RDA
RES.RDR
RES.RDT
LANG.DAT
OS.DAT
INTRO.MPX
COMPLETE.MPX
```

## Launcher evidence and current blocker

The earlier recipe incorrectly treated an `OB.EXE` process/window as success. Fresh end-to-end revalidation showed two important things:

1. The launcher plumbing now works correctly:
   - `install.sh --existing --no-launch` validates `OVERBOARD.iso`
   - `launch.sh` no longer fails with `Directory name invalid.`
   - the launcher starts `D:\\OB.EXE` from the mapped CD root
   - default launch now uses a Wine virtual desktop so blocking dialogs are visible

2. The game is still blocked by its built-in CD check.

Verified process/window evidence from the current recipe:

```text
C:\\windows\\system32\\explorer.exe /desktop=Overboard,800x600 D:\\OB.EXE
D:\\OB.EXE
WM_NAME = "Overboard - Wine Desktop"
```

Captured virtual-desktop screenshot shows:

```text
Overboard! CD Validator
OVERBOARD! CD NOT PRESENT
Please place the Overboard! CD into your CD-ROM drive.
```

Additional bounded-launch evidence from the current wrapper/debug runs:

```text
wine32 cmd /c "cd /d d:\\ && OB.EXE"                    -> exit 0
OVERBOARD_VIRTUAL_DESKTOP=1 ./launch.sh                  -> exit 1
wine32 start /exec explorer /desktop=Overboard,800x600 D:\\OB.EXE -> exit 1
OVERBOARD_MEDIA_MODE=cuebin ./launch.sh                  -> still shows Overboard! CD Validator, exits 1
ISO/data-track path                                      -> fixme:mcicda:MCICDA_GetError Unknown mode 1
ISO loop/device path                                     -> fixme:mountmgr:harddisk_ioctl Unsupported ioctl 24008
cue/bin-backed path                                      -> fixme:vxd:__wine_vxd_open Unknown/unsupported VxD L"d:.vxd"
```

So the title can start `OB.EXE` and then still fail back out through the same CD-audio/original-disc validation path; a clean process exit is not evidence of gameplay.

This blocker remains even after all of the following were verified:

```text
Volume in drive d is OVERBOARD
Directory of d:\
OB.EXE
```

And even after trying all of these media paths:

1. extracted converted ISO directory as `d:`
2. real loop-mounted ISO as `d:` plus `d:: -> /dev/loop0`
3. cue/bin-backed Wine mapping where the extracted data stay on `d:` but `d::` points at a loop device for the original `OVERBOARD.bin`
4. Windows 10 mount of the original `OVERBOARD.cue` (ProcMon capture attached as `Logfile.PML`)

The ProcMon file is not easily decoded on this Linux host, but printable strings confirm the Windows run reached both `F:\\OB.EXE` and the installed copy `C:\\Program Files (x86)\\Psygnosis\\Overboard!\\Ob.exe`, with the mounted disc seen as `CDFS`. Since the same CD-check still reproduced on real Windows 10, the blocker is now much less likely to be Wine-specific and much more likely to require a more faithful original-disc / mixed-mode-audio presentation than a normal virtual mount provides.

That strongly suggests the game wants more than a plain ISO9660 data track — most likely true mixed-mode CD emulation with an audio TOC/original-disc semantics.

## Additional repo/infra learnings

- `install.sh` originally failed during validation because the shared helper used `mktemp` under `/tmp`; on this machine `/tmp` can fill up with old AppImage extraction leftovers and trigger misleading `Disk quota exceeded` errors from the `7z | awk` pipeline. The shared helper was fixed to create the temporary path list beside the image (fallback `/var/tmp`).
- `launch.sh` originally used `cmd /c "cd /d <full-exe-path> && OB.EXE"`, which produced `Directory name invalid.`. The fix is to `cd /d D:\\` and then run `OB.EXE`.
- Earlier experiments added extra `e:`/`f:` CD-ROM mappings and MCI registry hacks. They did not satisfy the validator and are now removed from the canonical recipe to keep future debugging evidence-based.
