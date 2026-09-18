# Overboard! / Shipwreckers! notes

## Aktuel status: window mode med intro godkendt

Brugeren godkendte den sidste 1024×768-vinduestest: introen virkede perfekt og spillet oplevedes mere flydende. Den afgørende kombination er 16-bit Xephyr, Wine Explorer-skrivebord, Gamescope med bevaret billedformat, størrelseshjælper READY før spilstart og normal drift uden tung debuglog. Fuldskærmsforsøget blev forkastet; brugeren ønsker et almindeligt vindue.

Den fulde forklaring, fejlslagne forsøg, begrænsninger og erfaringer til andre projekter er samlet i [DISPLAY-FIX.md](DISPLAY-FIX.md). AppImage-kilderne er opgraderet; den tidligere pakke er bevaret som `Overboard-classic-backup-x86_64.AppImage`. Godkendelsen af den selvstændige test og valideringen af den genbyggede pakke holdes adskilt.

Alt nedenfor er kronologiske undersøgelsesnoter. Ældre udsagn om manglende skalering, kun Esc-løsning eller afventende testgodkendelse er historiske og erstattes af status ovenfor.

## Fixed outer resolution: positive scaled-video test

A later isolated test combines Gamescope (SDL/X11 backend, `-W 640 -H 480 -w 640 -h 480 -S fit -F linear`) with Xephyr (`:4 -screen 640x480x16 -resizeable -nolisten tcp -noreset`) and Wine-GE Explorer desktop `OverboardFixed,640x480`. Direct game launch without Explorer was black in this stack; the Explorer desktop path displays video.

The important missing step was following the Wine desktop's actual dimensions: during movies that window becomes 320x240 while Xephyr initially stayed 640x480. Changing Xephyr's RandR mode to 320x240 lets Gamescope scale the full movie area into an unchanged 640x480 outer window. A private `follow_size.py` watches only `OverboardFixed - Wine desktop` on display :4 and switches Xephyr between its supported modes as Wine changes size.

Verified screenshots: `local/runtime/overboard-fixed-screen/scaled-intro.png` shows the animated movie across the full width with correct letterboxing; `fixed-current.png` shows the subsequent rendered harbor/demo scene. Geometry checks confirm outer 640x480 throughout; inner switches from 320x240 to 640x480, remaining 16-bit. This supersedes the earlier finding that video could only be shown small. Interactive controls, sound and sustained gameplay in this stack still await user confirmation. The existing AppImage has NOT been changed. Private test files are in `local/runtime/overboard-fixed-screen/`.

## Dansk resumé: introvideo og færdig AppImage

Brugeren har efter testen bekræftet, at AppImage'en virker som den skal. Introeksperimenterne er ikke med i denne pakke; den stabile version bruger fortsat Esc til at springe den sorte intro over. Denne status erstatter de ældre forbehold nedenfor om manglende AppImage-bekræftelse.

Introen havde tydelig lyd, men sort billede. De fem installerede MPX-filer matchede cd-kopien byte for byte. Spillet ser ud til selv at afkode Psygnosis' MPEG-1/MPX-variant og vise billederne gennem DirectDraw; vi fandt ikke belæg for blot at installere et manglende Wine-codec.

Gennembruddet var et separat Xephyr-vindue med 16-bit farvedybde. Med Wine-GE 7-43 og de uændrede videofiler kunne vi se både Psygnosis-logoet og den animerede intro. Den normale sorte visning brugte en 32-bit RGB-billedflade; den fungerende test brugte 16-bit RGB565. Det peger stærkt på et farvedybdeafhængigt problem i afkodnings-/visningsvejen, men den præcise fejl i koden er ikke bevist.

Billedet kom frem i originalopløsningen 320×192, placeret i et 320×240-område øverst til venstre i et 640×480-vindue. Derfor fyldte det ikke vinduet. Korrekt opskalering og efterfølgende 3D-gameplay i denne testopsætning blev ikke verificeret.

Forsøg med dxwrapper for at kombinere 16-bit med opskalering mislykkedes: Dd7to9 gav en fejl om utilstrækkelig 3D-acceleration, og native DirectDraw-wrapper med tvungen 16-bit udløste en Wine-assertion. GDI gav stadig sort billede; Wine 11-testen nåede ikke en brugbar videotest. Alle forsøg foregik i separate testmiljøer. Ingen video blev konverteret, og den fungerende spilinstallation blev ikke ændret.

Konklusion: originalvideoerne kan afspilles med billede under Wine i den isolerede 16-bit-test, men en stabil, korrekt skaleret løsning sammen med gameplay mangler. Derfor blev den sikre Esc-løsning beholdt i AppImage'en.

## Virtual-CD and intro investigation

- CDEmu/VHBA on kernel 7.2.5 loads the user's original `local/sources/overboard-original-cd/OVERBOARD.toc`/`.bin`. A dedicated device 1 was allocated because device 0 belonged to Global Operations; never assume `/dev/sr0` is physical after reboot. `cdemu device-mapping` mapped Overboard to `/dev/sr1`, mounted at `/run/media/test/OVERBOARD`; ioctl returned tracks 1–31. Wine `d::` in the separate `overboard-image-test/wineprefix-ge` points to this virtual device. User confirmed clear audio; explicit physical-disc-removal/gameplay confirmation remains separate.
- Original backup: BIN 754519248 bytes, SHA256 `4675345cbc68d574e41ef28f6d8275a502b82a3f6cd33cf510f765c4045ac40f`. TOC references all bytes correctly; the 150-sector difference from the physical leadout is represented as `SILENCE 00:02:00`. cdrdao completed successfully but reported 394 Q-subchannel CRC errors; do not describe it as a perfect subchannel dump.
- Installed MPX SHA256 hashes match the virtual CD for all five movies. The EXE imports DirectDraw and contains decoder diagnostic strings; the movie headers identify Psygnosis MPEG-1 animation. Generic ffmpeg gives slice errors and corrupt-looking frames, so transcoding these files as ordinary MPEG is not a justified fix.
- Reproduced black video with clear audio. Wine DirectDraw trace shows the intro locking/unlocking a 320x240 **32-bit RGB** primary surface. GDI rendering also remained black. A separate Wine 11 prefix upgrade stalled and did not provide a meaningful video comparison.
- **Positive control:** local Xephyr `:2 -screen 640x480x16 -nolisten tcp -noreset`, then the GE runner with `DISPLAY=:2`, an isolated prefix, and `explorer /desktop=Overboard16,640x480` visibly plays both the Psygnosis logo and actual animated intro. Xlib confirms root depth 16; DirectDraw confirms 16-bit RGB565, pitch 640. Original MPX assets were unchanged. Screenshots: `local/runtime/overboard-intro-test/depth16.png` and `depth16-film.png`; user also confirms picture. This strongly isolates the black-video failure to the 32-bit display path rather than absent Wine MPX codecs.
- The Xephyr result is diagnostic, not a finished launcher: the native 320x192 movie sits inside a 320x240 area at the upper left of a 640x480 window. Scaling and subsequent 3D gameplay in this environment are NOT verified.
- Tried upstream dxwrapper v1.8.8600.25 in the isolated intro prefix only. Dd7to9 mode showed `Machine does not contain sufficient 3D Acceleration hardware`; native `EnableDdrawWrapper=1` plus `DdrawOverrideBitMode=16` hit Wine's `d3d_viewport_vtbl` assertion in `ddraw/viewport.c`. Neither is promoted. The normal physical and virtual gameplay prefixes remain untouched. Test windows/Xephyr were stopped.
- Keep the normal working gameplay path with Esc until a scaled 16-bit presentation path also passes gameplay verification. No movie replacement or executable patch has been applied.

## Original physical-CD recovery (supersedes image-only status)

- Physical source verified by `findmnt`: `/run/media/test/OVERBOARD`, `/dev/sr0`, ISO9660 read-only, lowercase filenames. Do not use the old extraction helper against this mount: it writes labels and may remove/re-extract its CD directory.
- System Wine 11 win32 bootstrap timed out; the failed prefix was retained separately. Wine-GE 7-43 bootstrap completed in `local/runtime/overboard-physical/wineprefix-ge`.
- Original Win16 `setup.exe` completed interactively. It installed `C:\Program Files\Psygnosis\Overboard!\Ob.exe` and supplied the genuine installed paths/registration. No game executable patches or CD-check bypass were applied.
- Prefix Windows version read back as `win98`; `vol d:` returned `OVERBOARD`; `d:` points to the mounted CD and `d::` to `/dev/sr0`.
- Launch: selected GE runner, `wine explorer /desktop=Overboard,800x600 'C:\Program Files\Psygnosis\Overboard!\Ob.exe'`, with working directory `local/runtime/overboard-physical`.
- Initial window was black. User pressed Esc, reached the main menu, started a new game, and reported everything working perfectly. A subsequent screenshot shows the actual harbor/ship scene with pause menu. This is gameplay evidence, unlike the earlier image tests.
- Intro remains unresolved. `ffprobe` identifies `intro.mpx` as MPEG-1 video, 320x192, but reports `slice below image`; this alone does not establish corruption or justify transcoding the game's MPX container. Preserve original assets and use Esc for now.
- New `launch_cd.sh` preserves this command and maps only the prefix drive links. Automated checks passed, but this wrapper has not yet been relaunched end-to-end because the user's confirmed game session was left running.
- Screenshots/logs remain private in `local/runtime/overboard-physical/logs/`; `game-after-escape.png` captures the in-game scene. No CD-free AppImage claim: true physical mixed-mode media is the verified path.

## Historical image investigation


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
