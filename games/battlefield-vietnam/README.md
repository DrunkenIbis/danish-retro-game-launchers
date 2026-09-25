# Battlefield Vietnam

## Current result and recommended launch

From the repository root, run `games/battlefield-vietnam/launch.sh`.
It starts the folder-only `simple121-ge7` runtime: original installation →
official full 1.2 → official incremental 1.21 → optional third-party SiMPLE 1.21.
`launch_physical.sh` is retained for original CD/setup and historical controls.

- Original retail v1.0 and official-only v1.21: user-confirmed physical-CD gameplay.
- Separate SiMPLE 1.21 folder: user described disk-free gameplay as “perfect”.
- Real AppImage: built and user-confirmed with fresh writable state, then the
  same existing state at `local/runtime/battlefield-vietnam/appimage-test-fresh`.
  Latest confirmation covered movement, shooting, sound and menu exit.
- Agent visual evidence: `gameplay-restart.png` shows first-person gameplay,
  gun, HUD and minimap. Earlier physical-CD screenshots covered intro only.
- `/proc` inspection proved both wine-preloader and wineserver ran from the
  AppImage mount, not host Wine. Physical tray was open (drive status 2), CDEmu
  empty, with no loop devices or mounted game images available as fallback.
- Final cleanup: no processes belonging to the test prefix, no Battlefield
  AppImage mount and no loop devices remained. Wrapper exit 1 was the user's
  confirmed normal exit, not a crash; no zero-exit claim is made.

The exact private artifact is
`/home/test/danish-retro-game-launchers/local/appimage-dist/Battlefield-Vietnam-1.21-SiMPLE-x86_64.AppImage`.
SHA-256: `dc12b544f7c17c0a13d8f39b1b81d5b53ba3c96bc4bc44884a2f8cf51e173388`.
See [AppImage build and runtime details](extras/README.md). Compatibility beyond
this machine is unverified. Online play and mods have not been verified.

All game data, media, keys/registration, prefixes, manifests, screenshots, logs
and packages remain private. Never distribute the installed tree or AppImage.
SiMPLE is not an official EA update or an unchanged-executable route.

## Recreate from a clean checkout

Commands below run from the repository root and use the default private paths.
Supply your own original three CDs and enter your key only in the original
installer UI, with no tracing or screenshots of filled key fields. Obtain and
extract the tested runner privately to
`local/runners/lutris-GE-Proton7-43-x86_64` (with `bin/wine` and `bin/wineserver`).
Its actual version is `wine-5.12-15762-ge9a47cbabb9 (Staging)`; win32 and Windows
XP mode were tested. No old DirectX/graphics drivers were installed.

Dependencies: Bash, Python 3.11+, coreutils, util-linux, a graphical desktop and
compatible 32-bit runner graphics/system libraries. Runner acquisition and
system packages are not automated. `BFV_WINE` can override the physical/folder
launcher, but the patch/preparation helpers and builder require the fixed runner
path above. These reproduction commands assume no runtime/source overrides.

1. Insert BFV_1 and mount it read-only (for example `udisksctl mount -b /dev/sr0`).
   Verify the actual device and mountpoint; use `BFV_DEVICE` and `BFV_CD` if the
   defaults `/dev/sr0` and `/run/media/$USER/BFV_1` differ.
   Run `games/battlefield-vietnam/launch_physical.sh check`, then
   `games/battlefield-vietnam/launch_physical.sh setup` in a previously unused
   default `physical-ge7` runtime. Choose the game, omit optional online/editor
   tools and old DirectX/driver additions. Swap CDs on request. For stale mount
   recovery, use the historical staging instructions below; CD 3 needs its loose
   `Support/English/UK` files as well as its CAB. Use the staging root as the
   installer Path through Wine Z:.
2. Finish setup (Register Later), wait for the wrapper to return, reinsert and
   verify BFV_1, then run `games/battlefield-vietnam/launch_physical.sh game`.
   Confirm gameplay and close the game. Before copying, ensure no setup/game
   wrapper is running. Create the **preserved stopped prefix** required by
   `patch-official.sh prepare`; setup does not create this snapshot itself:

   ```sh
   (
     set -eu
     BASE="$PWD/local/runtime/battlefield-vietnam"
     SERVER="$PWD/local/runners/lutris-GE-Proton7-43-x86_64/bin/wineserver"
     exec 9>"$BASE/physical-ge7/.lock"
     flock -n 9
     test -f "$BASE/physical-ge7/prefix/system.reg"
     test ! -e "$BASE/physical-ge7/prefix-gameplay-confirmed"
     test ! -L "$BASE/physical-ge7/prefix-gameplay-confirmed"
     WINEPREFIX="$BASE/physical-ge7/prefix" timeout 20 "$SERVER" -w 9>&-
     cp -a --reflink=auto -- "$BASE/physical-ge7/prefix" \
       "$BASE/physical-ge7/prefix-gameplay-confirmed"
   )
   ```

   A timeout is a stop condition, not permission to copy a live prefix. Preserve
   existing snapshots; never overwrite them to make preparation succeed.
3. Obtain the official installers listed below into
   `local/sources/battlefield-vietnam/patches/` and verify their SHA-256 hashes.
   The incremental archive's long-named EXE must be saved as `bfv_v1_21.exe`.
   Run each command separately, completing each interactive installer:

   ```sh
   games/battlefield-vietnam/patch-official.sh prepare
   games/battlefield-vietnam/patch-official.sh 1.2
   games/battlefield-vietnam/patch-official.sh 1.21
   ```

   Preparation requires a nonexistent `patch121-ge7` destination. Verify
   `INSTALLEDVERSION` is `1.20.001`, then `1.21.001`, without exposing other
   registry data. The observed original installers both exited 0; that alone
   is not gameplay evidence. Confirm official-only gameplay with BFV_1 using
   `BFV_RUNTIME="$PWD/local/runtime/battlefield-vietnam/patch121-ge7" games/battlefield-vietnam/launch_physical.sh game`,
   then close it and wait for its Wine session to end.
4. Obtain and hash-check the optional SiMPLE archive below at the same patches
   directory. Run `games/battlefield-vietnam/prepare-simple.sh`. It checks the
   stopped official 1.21 prefix and archive layout, clones to `simple121-ge7`,
   and refuses to overwrite an existing destination. It preserves retail and
   official-only copies. The private `simple-manifest.json` records before/after
   hashes. Run `games/battlefield-vietnam/launch.sh` for disk-free play.
5. Close the game before building with
   `games/battlefield-vietnam/extras/build_appimage.sh`. See extras for build
   dependencies, state directories and the exact artifact verification.

## Patch sources and integrity

These are local integrity hashes, not publisher-authenticated checksums.
No patch binaries are provided in Git.

| Local filename | Source | SHA-256 |
| --- | --- | --- |
| `bfv_v1_2.exe` | https://ftp.bf-games.net/patches/bfv/bfv_v1_2.exe | `db136d5f14d894a38f073e4eee8bc11e1e3d9b9badebe3b7e8221be922bdaa44` |
| `bfv_v1_21.exe` | https://www.patches-scrolls.com/dl.php?file=bfv12to121.zip — extract `battlefield_vietnam_incremental_patch_v1.2_to_v1.21.exe` and save under the local filename; download may require its session cookie and Referer | `a9064d5d463aca549c79a662e4dc106f2e005fc481d8200f164f49431e5a84dd` (EXE) |
| `bfvietnam-v1.21-patched.zip` | https://team-simple.org/download/bfvietnam-v1.21-patched.zip | `b419f57ec0f6e7503064daac1ce4dbfe52e572f0d56830aedeea2a78baad60dc` |

SiMPLE supplies four installed-file replacements relative to the game root:

| File | Installed SiMPLE SHA-256 |
| --- | --- |
| `BfVietnam.exe` | `e8144209cc8b533c83e25173957f09667cfe8b9e694b8d78c1b5368e29c9c983` |
| `Mods/BfVietnam/Mod.dll` | `4b1af774123ec099f23d22270352d4c2e579aa13297c8d7b13787c062c098125` |
| `Mods/BfVietnam/init.con` | `31b78ec22039defe11f456f58ee3c491e365323fb7666a3c3f80b908f111b13d` |
| `Mods/BfVietnam/LevelCheck.con` | `7c549928bf632e2812bae40cee6e1e4a1e5a26d1762864357fd094d61a87edff` |

The manifest shows the EXE and DLL changed bytes; both `.con` replacements were
byte-identical to this official 1.21 source. The third-party package removes the
CD check and advertises widescreen and GameSpy/Qtracker changes; those online
features and mods are not verified here.

## Backups and automated checks

`backup-disc.sh BFV_1` (then BFV_2/BFV_3 after swaps) requires `cd-info` and GNU
ddrescue (`BFV_DDRESCUE` can select a private executable). Existing image/map
pairs are refused. Incomplete copies retain logs/maps and return nonzero even
if ddrescue itself exits zero. `audit-rescue-iso.py IMAGE MAP REPORT` audits
filesystem extents; optional `7z t IMAGE` does not prove sector completeness.
All three observed rescue images have unrecovered sectors despite good file
coverage audits. They are **not complete archival backups** and do not establish
protection/subchannel fidelity. Detailed historical measurements follow below.

Verified separately from gameplay: **19 recipe tests** and **1 multi-case
AppImage synthetic test** passed:

```sh
python3 games/battlefield-vietnam/test_recipe.py -v
python3 games/battlefield-vietnam/extras/test_appimage.py
```

The physical launcher leaves the owner's CD mount alone. Historical image
scripts require separately mounted test-owned media and do not own its lifecycle;
stop their Wine session before unloading only their own mounts/devices. Never
unload unrelated media. The historical failures below are not current SiMPLE
or AppImage failures.

## Identified media and sources

Physical ASUS SDRW-08D2S-U at `/dev/sr0` (the separate CDEmu drive is not
this original). CD 1 label `BFV_1`; CD 2 raw ISO9660 descriptor `BFV_2`.
CD 1's `Support/English/UK/eReg/readme.txt` identifies v1.0, January 16,
2004. `Setup.ini` identifies Battlefield Vietnam with eight language options.
`Autorun.inf` starts `Autorun.exe`; the actual installation is `Setup.exe`.
Both are PE32/i386 Windows GUI applications. No separate DOS installation
route was identified. SecDrv/DrvMgt files are present; this is a protection
risk, not evidence of a failed gameplay test.

Sources reviewed:
- https://www.systemrequirementslab.com/cyri/requirements/battlefield-vietnam/10320
- https://www.gamersonlinux.com/forum/threads/battlefield-vietnam-guide.1908/
- https://forum.helloclan.eu/threads/9090/
- https://www.pcgamingwiki.com/wiki/Battlefield_Vietnam
  (retail SafeDisc 2; official update order: full 1.2, then incremental 1.21).
  Windows Vista/later driver restrictions do not prove the same failure under
  Wine: this original version already has user-confirmed physical-CD gameplay.
  Similar unread regions outside allocated filesystem extents on all three
  discs are consistent with protection-related sectors, not proof of a broken
  drive. Hardware comparison with another drive has not been performed.
  Subsequent official-update and separate SiMPLE results are documented above;
  do not mix a version-specific replacement with the original v1.0 install.
- WineHQ search result (full test report not reviewed): https://appdb.winehq.org/objectManager.php?sClass=version&iId=10455&iTestingId=97223

The CD readme specifies Windows 98/ME/2000/XP, DirectX 9.0b, 933 MHz CPU,
256 MB RAM, GeForce3-class 64 MB graphics and 2 GB free disk space.
The GamersOnLinux guide reports retail installation with Wine 1.8.4 and
cabinet files from multiple discs in one installation directory. Its extra
font/D3DX packages are not established as necessary here and were not added.
HelloClan reports running an existing installation using Wine 5; that is not
proof that this unpatched retail edition runs without optical media.

## Historical original installation experiment

From repository root:

```sh
games/battlefield-vietnam/launch_physical.sh check
games/battlefield-vietnam/launch_physical.sh setup
# Only after original setup completes:
games/battlefield-vietnam/launch_physical.sh
```

This historical physical launcher uses the user-confirmed original-CD route
and `scripts/common.sh` for runtime paths. Normal disk-free play now uses
`launch.sh`, not this physical launcher.
Default runtime: `local/runtime/battlefield-vietnam/physical-ge7`.
Default existing runner: `local/runners/lutris-GE-Proton7-43-x86_64/bin/wine`.
Its actual `--version` output is `wine-5.12-15762-ge9a47cbabb9 (Staging)`;
the directory name alone must not be treated as its reported Wine version.
Uses its sibling wineserver, a new win32 prefix and Windows XP mode.
XP is documented as supported by this game; the GE runner was chosen as an
original-InstallShield baseline based on sibling projects, not as a proven
Battlefield renderer solution. No old DirectX or NVIDIA driver was added.

Overrides: `BFV_RUNTIME`, `BFV_WINE`, `BFV_CD`, `BFV_DEVICE`, and shared
`RETRO_GAME_RUNTIME_DIR`. Runtime/Wine overrides must be absolute paths.
Keep alternate runner experiments in separate runtimes. Do not copy a live
prefix. The script closes its lock descriptor in Wine children and waits for
the paired wineserver after the main application exits.

User-provided screenshots establish component selection, a blank CD-key
entry dialog, the installer detecting DirectX and saying installation is not
needed, and the request for CD 2 containing `data3.cab`. Those intermediate screenshots alone did not establish
installation completion; later completion and gameplay were confirmed. The user enters their own key in the original UI;
never capture filled key dialogs or publish installer-created registry data.
For first singleplayer validation, choose only Battlefield Vietnam Game;
leave optional PunkBuster/editor/toolkit/server/downloader components out.

## Historical CD 2 swap: stale ISO9660 mount

After the physical swap, `lsblk` and Wine show BFV_2, but the original
`/run/media/test/BFV_1` mount exposes DirectX files instead of the CD root.
The installer/IKernel and file manager hold the old mount open. A second
read-only mount, performed by the user with administrator privileges, also
exposes the stale listing. Do not claim it fixed the swap or forcibly unmount
an installer-held filesystem.

Direct read-only parsing of `/dev/sr0` verified the BFV_2 root contains
`DATA3.CAB;1` (564224000 bytes). To stage this original installation cabinet
without depending on stale filesystem entries:

```sh
python3 games/battlefield-vietnam/stage-disc-cab.py \
  --device /dev/sr0 --label BFV_2 --cab data3.cab \
  --output-dir "$PWD/local/runtime/battlefield-vietnam/install-media/disc2"
```

If interrupted, repeat with `--resume`: it verifies existing partial bytes
against the current original disc before appending. Read errors abort; no
zero substitution is used. Successful output is SHA-256 checked against the
bytes read before `.partial` is renamed to the final CAB. This is only
installation staging, NOT a complete archival backup or optical-disc image.
Only after successful completion, point the installer's next-disc Path to:

`Z:\home\test\danish-retro-game-launchers\local\runtime\battlefield-vietnam\install-media\disc2`

That example is this machine's private staging directory, not a portable
launcher default. Other checkouts must use their actual staging path.

The additional user-created mount was at
`local/runtime/battlefield-vietnam/cd2-mount`. Final cleanup confirmed no
remaining game-media mounts; never interrupt active reads or installer use.

## Historical installation, backup and original-media trial evidence

- Automated: shell syntax, dry-run and physical-CD preflight passed.
- Visual: user screenshots of installer steps reviewed by agent.
- Installation: completed through the original Windows installer; staged CD 2
  and CD 3 files were accepted.
- CD 2 staging: `data3.cab`, 564224000 bytes, SHA-256
  `fe71858aa8d4f346c95d982facce87dfda60a3002a479ed7fab053e8afa3c29d`.
  Interrupted copy resumed after verifying existing bytes against original;
  completed successfully with no reported read errors. This is not a disc backup.
- CD 3: physical `/dev/sr0` raw ISO9660 descriptor verifies `BFV_3` and
  `DATA4.CAB;1`, 248625327 bytes. Staging completed successfully using
  `--label BFV_3 --cab data4.cab --output-dir <private-runtime>/install-media/disc3`.
  SHA-256: `ca86e882662191c1582b2af193f91b5c91f295490a644ff1467c96eb71f8c904`.
  No read errors reported. Setup subsequently requested the loose CD 3 file
  `Support\English\UK\Movies\EA.bik`; cabinet-only staging is insufficient.
  The helper now supports `--file Support/English/UK/Movies/EA.bik`, preserving
  the directory structure under the same disc3 staging root. This file was
  copied and verified: 1131548 bytes, SHA-256
  `f98849e0590f131667af7632317fcbf0342237696e7de4fcb4daae8b1ceaf7f4`.
  The entire original `Support/English/UK/eReg` directory was subsequently
  staged recursively with `stage-disc-directory.py`: all 8 source files were
  verified byte-for-byte/read-back SHA-256, including previously staged files.
  Private manifest: `physical-ge7/logs/disc3-ereg-manifest.json` under runtime.
  Reproduce with `--device /dev/sr0 --label BFV_3
  --directory Support/English/UK/eReg --output-dir <private-disc3-directory>
  --manifest <new-private-manifest.json>`. Existing differing files are preserved
  and cause an error rather than being overwritten. The helper uses Joliet
  long filenames and preserves the directory structure.
  Original installer completion was visually confirmed from the user screenshot;
  its process exited 0 and the installed bfvietnam.exe was verified.
- Physical-CD gameplay: user confirmed that the game worked as it should.
  Agent screenshot verified intro playback only. First run ended with
  SIGKILL/137. In the later physical-CD control, the user confirmed gameplay
  and that they closed the game themselves; wrapper exit was 1. Paired
  wineserver wait subsequently confirmed no remaining Wine session. Do not
  treat exit 1 alone as a game crash or claim a zero-exit result.
- Preserved stopped prefixes: `physical-ge7/prefix-installed-original` and
  `physical-ge7/prefix-gameplay-confirmed`, under the private runtime.
- CD 1 TOC: physical ASUS /dev/sr0, BFV_1; one Mode 1 data track, LSN 0,
  leadout LSN 324288, no audio tracks. First-pass rescue ISO completed with
  unread areas: 664141824-byte image, SHA-256
  `025d456c4831fdf2c75790a926b3472cfac736cd964e0cfb0908d7ab3f615409`.
  646033408 bytes read; 18108416 bytes not recovered. Map states:
  `-` 104448, `*` 624640, `?` 17104896, `/` 274432 bytes. ddrescue reported
  86 read errors. This is NOT a complete sector-level archival backup.
  `audit-rescue-iso.py` checked 384 records across both primary trees and
  the Joliet tree: no file/directory/path-table extents overlap unread areas.
  `7z t` passes (95 files, 30 folders). These checks establish filesystem
  read coverage, not raw-media/protection fidelity or game acceptance.
  Private output: `local/sources/battlefield-vietnam/backups/`, with TOC,
  rescue map, log, coverage audit and SHA-256/integrity report. ISO does not
  preserve raw subchannel/protection information.
- CD 2 TOC: BFV_2 at physical /dev/sr0, one Mode 1 data track, LSN 0,
  leadout 323484. Rescue ISO: 662495232 bytes, SHA-256
  `603a16e5f0a36e8455797b3ab291897fcad5f4619811190dc9336223c763de7d`.
  643768320 bytes recovered; 18726912 unrecovered. Map states:
  `-` 57344, `*` 479232, `?` 18087936, `/` 102400 bytes.
  Coverage audit: 342 records checked across both primary trees and Joliet;
  none overlap unread areas. `7z t` passes (85 files, 26 folders).
  This is a filesystem-readable rescue copy, not a complete sector backup.
- CD 3 TOC: BFV_3, physical ASUS /dev/sr0, one Mode 1 data track,
  leadout LSN 249224. ISO size 510410752 bytes, SHA-256
  `f49a03ed643da0b6185bfbdafcf966193a81636ec80460ca57cc7121f63dc891`.
  492630016 bytes recovered; 17780736 unrecovered. Map states:
  `-` 135168, `*` 581632, `?` 16711680, `/` 352256 bytes.
  Coverage audit: 465 records, no affected file/directory/path-table extents.
  `7z t` passes (119 files, 33 folders). Still not a complete sector backup.
- Folder-only diagnostic (`launch_folder.sh`, separate `folder-ge7/prefix`):
  visually fails with "Please insert the correct CD-ROM". Physical /dev/sr0
  was verified tray-open via CDROM_DRIVE_STATUS=2; no loop devices/mounts,
  and CDEmu empty. Wine recreated raw optical links but no disc was available.
- Ordinary mounted-ISO diagnostic (`launch_mapped.sh`, `loop-ge7/prefix`):
  visually produces the same CD error. D: was the verified BFV_1 loop mount;
  D:: was the ISO file because the UDisks loop block device was not readable
  as this user. This does not establish results with a readable raw loop device.
- CDEmu diagnostic: loaded this exact BFV_1 ISO into previously empty device 0,
  verified /dev/sr1 (CDEmu) mounted as BFV_1 and physical /dev/sr0 tray open.
  `BFV_RUNTIME=<private-runtime>/cdemu-ge7 BFV_DEVICE=/dev/sr1
  BFV_CD=/run/media/test/BFV_1 games/battlefield-vietnam/launch_physical.sh game`
  exits 0 without a captured game window. A separate `cdemu-fresh-ge7` copy
  of the original installed prefix has the same result, so saved gameplay
  settings alone do not explain it. Debug trace shows
  `Initialization of L"mod.dll" failed`, following handled/dispatch exceptions.
  This is a startup blocker, not a verified CD-check pass or gameplay result.
  Physical-CD control of this exact `cdemu-fresh-ge7` prefix now reaches
  visually verified intro playback with WINEDEBUG=-all. The physical read
  needed longer than the initial five-second window check. Identical game EXE
  SHA-256 across source and test copies:
  `0fdab9bddea5024e2af89ca39da916beec1a9f35d231657ee4566b9054716d51`.
  This isolates an image/emulation-dependent startup difference; it does not
  identify which original-media property is missing from the rescue ISO.
  A verbose `warn+all,err+all,+seh` physical control hit Wine's
  `wine_dbg_output: debugstr buffer overflow` assertion; treat that crash as
  an instrumentation side effect, not the normal physical-CD result.
  User confirmed this physical control also worked and that closure was
  user-initiated. Paired wineserver wait confirmed the session had ended.
  This trial used unchanged retail binaries; the later separate SiMPLE route
  does replace the executable and Mod.dll.
- Test-owned loop and CDEmu mounts were removed; subsequent `cdemu status`
  verifies empty and `findmnt`/`losetup` show no optical/image mounts.
  Original/preserved prefixes remain untouched.
- Official update experiment: separate `patch121-ge7/prefix`, copied from the
  stopped `physical-ge7/prefix-gameplay-confirmed` using `patch-official.sh prepare`.
  Run `patch-official.sh 1.2`, then `patch-official.sh 1.21` interactively.
  Both installers exited 0; registry INSTALLEDVERSION changed to 1.20.001,
  then 1.21.001. User confirmed the updated game worked well with physical
  BFV_1 and that they closed it themselves (wrapper exit 1). This is user
  gameplay confirmation, not agent visual gameplay verification. Audio and
  prolonged stability were not separately confirmed. Original v1.0 preserved.
  Launch from repository root:
  `BFV_RUNTIME="$PWD/local/runtime/battlefield-vietnam/patch121-ge7" games/battlefield-vietnam/launch_physical.sh game`.
  Patch files belong in `local/sources/battlefield-vietnam/patches/`:
  - `bfv_v1_2.exe`: https://ftp.bf-games.net/patches/bfv/bfv_v1_2.exe
    SHA-256 `db136d5f14d894a38f073e4eee8bc11e1e3d9b9badebe3b7e8221be922bdaa44`.
  - `bfv_v1_21.exe`: original incremental installer from
    https://www.patches-scrolls.com/dl.php?file=bfv12to121.zip
    (download requires its session cookie and Referer); extracted original name
    `battlefield_vietnam_incremental_patch_v1.2_to_v1.21.exe`.
    SHA-256 `a9064d5d463aca549c79a662e4dc106f2e005fc481d8200f164f49431e5a84dd`.
    These are local integrity hashes, not publisher-authenticated checksums.
  Earlier failed disc-free trials above refer to retail v1.0, not SiMPLE.
  The official-only prefix remains separate from the modified SiMPLE copy.

Reference implementations inspected: Global Operations original-install/CD
and shared AppImage builder integration; FlipOut's unchanged-file folder
launcher. Their title-specific graphics/Windows settings are not copied.
All media, prefixes, logs and staging files stay in ignored private directories.
