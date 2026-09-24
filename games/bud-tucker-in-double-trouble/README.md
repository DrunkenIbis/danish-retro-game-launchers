# Bud Tucker in Double Trouble — BUD_USA (DOS CD)

## Status

- Original physical-CD installation completed through the original INSTALL.BAT → SETSOUND.EXE → INSTALL.EXE path in DOSBox-Staging 0.83.0 (existing user Flatpak).
- User confirmed playable gameplay, speech, music, sound effects and normal exit. Agent visually inspected the user's screenshot of Bud in the bedroom with the action interface, plus original installer and intro screenshots. This is not a full-game completion/stability test.
- DOSBox exited with code 0; process inspection found no remaining DOSBox before preservation.
- Preserved installation: `local/runtime/bud-tucker-in-double-trouble/physical-verified/c`. All 1444 files compared SHA-256-equal against the stopped installation; private manifest stored beside this directory.
- Local ISO backup read completely and passed `7z t`; no read errors.
- Folder-only/CD-independent gameplay and audio: user-confirmed working. Physical CD unmounted and ejected; CDROM_DRIVE_STATUS=2 (tray open), CDEmu empty and no loop devices. `launch.sh` uses C: and D: as ordinary local directories, no CD-ROM mapping or image mount. User confirmed normal game exit and automatic DOSBox closure; launcher returned 0. Agent has not visually captured folder-mode gameplay separately.
- Recommended `launch.sh` is now user-gameplay-verified. Stopped folder runtime preserved and hash-compared in `local/runtime/bud-tucker-in-double-trouble/folder-verified`.
- AppImage: user confirmed gameplay/audio both with fresh writable state and after restarting the exact same artifact with existing state. Both launches exited 0. User confirmed normal exit and automatic window closure. No DOSBox process remains; optical drives are unmounted, CDEmu empty, no loop device. Agent verified bundled runtime process path, not AppImage gameplay visually.

## Recommended folder launch without original disk

After closing the original installation session:

```sh
./games/bud-tucker-in-double-trouble/launch.sh prepare
./games/bud-tucker-in-double-trouble/launch.sh
```

Preparation extracts the owner's ISO with 7z, copies the completed original installation under its session lock, and refuses to overwrite an existing experiment. The unmodified installed BUD.BAT still resolves D:\TUCKER, but D: is now an ordinary directory rather than an optical drive. This is a local-file mapping experiment, not an executable or licence patch. ISO remains separate and is not opened during game launch. Test root: `local/runtime/bud-tucker-in-double-trouble/folder`.

Overrides: `BUD_FOLDER_RUNTIME`, `BUD_INSTALLED_C`, `BUD_ISO`, shared `RETRO_GAME_SOURCE_DIR` / `RETRO_GAME_RUNTIME_DIR`. Extra prerequisite for preparation only: 7z.

## Private AppImage (two starts user-verified)

Build after completing and testing the original installation and folder preparation:

```sh
./games/bud-tucker-in-double-trouble/extras/build_appimage.sh
./games/bud-tucker-in-double-trouble/extras/dist/Bud-Tucker-in-Double-Trouble-x86_64.AppImage
```

The builder reuses `scripts/wine-appimage-builder.sh` metadata/icon/packing functions and the existing pinned DOSBox download helpers from `games/gys-paa-regneslottet/extras/build_appimage.py`. No Wine is bundled or needed: this disc is DOS. Build input defaults to the stopped `folder` runtime, protected by its session lock; override with `BUD_BUILD_RUNTIME`. Tools are cached under ignored `local/cache/bud-tucker-in-double-trouble`. DOSBox-Staging 0.83.0 official native Linux release and appimagetool are SHA-256 checked. Native DOSBox is the same release version as the tested Flatpak, but is a different build and requires its own gameplay test.

The package bundles original files and the installed writable C: seed, not the ISO. Default writable state is `${XDG_DATA_HOME:-$HOME/.local/share}/bud-tucker-in-double-trouble`; `BUD_APPIMAGE_STATE` selects an absolute alternate state directory. First run seeds C: atomically; later runs preserve it. D: points to read-only files inside the current AppImage mount. No developer path is used by AppRun.

Build succeeded, 526763200 bytes. Extracted final artifact metadata/icon layout checked. Exact AppImage fresh-state launch used `local/runtime/bud-tucker-in-double-trouble/appimage-test-state`; `/proc/82970/exe` resolved to the AppImage mount's `runtime/dosbox`, proving bundled DOSBox, not host/Flatpak. The same artifact/state was reused for the second successful gameplay test. Both gameplay/audio results are user-confirmed, not inferred from startup logs. Save/load of an actual saved game and a full playthrough remain untested. The bundled README is the pre-test build snapshot; this recipe is the authoritative verification record.

Host still requires bash, coreutils, flock, compatible glibc/libstdc++, graphics/audio drivers, X11/XWayland and PulseAudio/PipeWire-Pulse. FUSE is required for normal AppImage mounting. No host Wine, DOSBox, Flatpak, CDEmu or VHBA is needed for this package. Cross-distribution portability remains untested. Build warning: optional AppStream metadata is absent; fallback icon is used. Package contains private copyrighted game files; do not publish it.

## Original installation

From repository root:

```sh
./games/bud-tucker-in-double-trouble/install.sh check
./games/bud-tucker-in-double-trouble/install.sh
```

Requires the owner's BUD_USA CD mounted read-only, by default `/dev/sr0` at `/run/media/test/BUD_USA`, Python 3, bash, util-linux (`findmnt`, `lsblk`, `flock`) and the already installed `io.github.dosbox-staging` Flatpak. No system packages/modules were installed.

Select Creative Labs Sound Blaster 16 or AWE32, automatic detection, OK, Done. Choose Full installation and `C:\TUCKER`. At the completed install's `C:\TUCKER>` prompt run `bud`. Exit the game normally, then type `exit` to close DOSBox.

Private writable C: is `local/runtime/bud-tucker-in-double-trouble/physical/c`; logs/config/lock live alongside it. Overrides: `BUD_CD`, `BUD_DEVICE`, `BUD_RUNTIME`, and shared `RETRO_GAME_RUNTIME_DIR`. `scripts/common.sh` supplies repository/runtime paths. The installer does not automatically re-run after returning to the DOS prompt. Do not rerun setup over a working installation for experiments: choose a new BUD_RUNTIME.

The configuration uses 16 MB guest RAM, SVGA S3, Sound Blaster 16 at port 220 / IRQ 7 / DMA 1 / high DMA 5. Fixed real-mode cycles are 30000; screenshots show protected-mode programs running at 60000 cycles/ms. These are locally tested settings, not published requirements. Primary/user DOSBox config is disabled for reproducibility. X11 access is scoped to each Flatpak invocation; no persistent permission override is installed.

## Media identity and backup

Physical device verified: ASUS SDRW-08D2S-U USB optical drive `/dev/sr0`; `/dev/sr1` was the separate empty CDEmu drive. Read-only ISO9660 label: BUD_USA. CD filesystem timestamp: 1996-08-29.

The disc has no AUTORUN.INF or Windows installer. INSTALL.BAT invokes sound setup and the DOS installer. DOS4GW.EXE is the DOS extender; INSTALL.EXE, INTRO.EXE, SETSOUND.EXE and TUCKER.EXE are DOS LE executables. The installed BUD.BAT starts the intro from D:\TUCKER and then the installed game from C:. Full installation does not itself establish CD independence.

TOC independently examined with `cd-info` and Linux CDROM ioctls: one Mode 1 data track starting LBA 0, leadout LBA 317696, no CD-audio tracks. Backup preserves all 2048-byte user-data sectors to leadout, not raw sector ECC/subchannel data.

```sh
python3 games/bud-tucker-in-double-trouble/backup_cd.py \
  --device /dev/sr0 --output local/sources/bud-tucker-in-double-trouble/BUD_USA.iso
7z t local/sources/bud-tucker-in-double-trouble/BUD_USA.iso
```

The script refuses existing output/report/partial files, reads the medium read-only, records the TOC/read failures, and independently hashes the saved output before finalizing it. Verify Mode 1 with `cd-info --no-analyze --cdrom-device=/dev/sr0` first; its ioctl track check distinguishes data/audio, not Mode 1/Mode 2.

- File: `local/sources/bud-tucker-in-double-trouble/BUD_USA.iso`
- Size: 650641408 bytes.
- SHA-256: `49aa9cabca6018ee2de5e42def2b108e5c91b65751e3e0aec31dbfc4368d82c3`
- Report: `BUD_USA.backup.json` beside the ISO, private.
- Read errors: none. Local read-back hash matches.
- `7z t`: Everything is Ok; 5688 files, 7 folders. Declared filesystem VolumeSpaceSize is 650022912 bytes; the ISO retains sectors through physical leadout. No integrity warning was emitted by 7z.

## Research and compatibility scope

- https://wiki.scummvm.org/index.php/Bud_Tucker_in_Double_Trouble — 1996, Merit Studios, DOS, 320×200/256 colours; ScummVM-supported data folders include AUDIO, FX, GRAPHICS, MUSIC, SPEECH, SPRITES and ENC/PCX/TXT/DTA files.
- https://www.scummvm.org/compatibility/2.1.1/tucker:tucker/ — published historical compatibility: Excellent, no known issues for DOS. Not a local ScummVM gameplay test.
- https://www.justadventure.com/2005/01/01/review-bud-tucker-in-double-trouble/ — search excerpt lists 486/33, 8 MB RAM, 2× CD-ROM, DOS 5.x and sound card; full article requirements not independently extracted.

ScummVM is a potential alternate engine, not used for the verified original-installation route. Wine compatibility is not applicable to these DOS executables. Global Operations and FlipOut recipes were inspected for private paths, original installation/media handling and isolated folder tests; their Wine settings and DRM findings are not inherited.

Original executables and licence checks have not been patched. Media, installed data, configuration, manifests, logs and future build output remain private and must not be committed.
