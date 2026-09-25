# Secret Weapons of WWII — separate original-media variant

Status: original installer completed (exit 0 and owner confirmation). Game-file audit found 52 added files, no changed or missing pre-existing files. Base init.con reports 1.61; XPack2 reports 1.6. Expansion archives and maps are present under `Mods/XPack2/Archives/bf1942/Levels` (lowercase bf1942, unlike the Road to Rome tree). Original shortcuts specify `BF1942.exe +game XPack2`. After paired wineserver stopped, `secret-weapons/prefix-installed` was preserved. Physical-CD expansion gameplay is now owner-confirmed ('det virker godt'); not an agent gameplay screenshot. After paired wineserver stopped, `secret-weapons/prefix-gameplay-verified` was preserved. CD 4 TOC: one Mode 1 data track, start LBA 0, leadout 334273, no audio tracks. Backup completed as an INCOMPLETE rescue ISO via `backup-disc.sh DISC_4_SECRETWEAPONS`. Source `/dev/sr0`; private output `local/sources/battlefield-1942/backups/DISC_4_SECRETWEAPONS.iso`. Expected/actual bytes 684591104; SHA-256 `77093ff8eccce89671dfe03a3a4aa31641b2ec508dd218439aaefed7892ea384`. ddrescue exit 0, but map bytes by status: + 665794560, - 67584, * 509952, ? 17956864, / 262144. Not all sectors were read; raw/subchannel/protection data is not preserved. Follow-up audit checked 438 ISO9660/Joliet file/directory/path-table records with none affected by unread regions; `7z t` passed. This verifies filesystem read coverage/readability, not full sector backup or image startup compatibility. Original CD was only read. Disk-free gameplay is owner-confirmed through `launch_secret_weapons.sh` with +game XPack2. Physical drive status 2 (open/empty), CDEmu empty and no external media mounts were checked before launch. The pinned SiMPLE archive was applied only to separate `secret-weapons-simple161b`; SHA-256 comparison preserved all 19 original expansion archives. A stopped `prefix-gameplay-verified` copy is preserved in that runtime. The exact separate AppImage is user-confirmed into gameplay with both fresh and reused writable state. On repeat start, /proc verified wine-preloader and matching wineserver from its AppImage mount. After each exit the exact test prefix had no processes and its recorded AppImage mount was removed. Both runs returned 1; the owner reported good gameplay, but normal Quit intent was not separately stated. These are user gameplay confirmations, not independent agent gameplay screenshots. Audio was not independently measured; multiplayer, long-term stability and other Linux hosts remain unverified. Artifact SHA-256 verification passes. Other variants remain unchanged.

## Original-media evidence

Physical ASUS `/dev/sr0`, volume `DISC_4_SECRETWEAPONS`, ISO9660 read-only mount `/run/media/test/DISC_4_SECRETWEAPONS`. CD root contains its own PE32 i386 Windows GUI `Setup.exe` and InstallShield cabinets. `Setup.ini` identifies `Battlefield 1942: Secret Weapons of WWII` (GUID B73B4A99-4173-4747-BBEC-0F05E966F9D2). No root autorun.inf observed. This is Windows setup, not a DOS or Win16 installation.

Original `Support/English/US/eReg/readme.txt` identifies v1.45, July 16 2003; mentions new air controls (positions 4/5/6) and maps Telemark, Hellendoorn, Eagle's Nest and Essen. A readme version alone does not establish installed Anthology payload version: inspect files/metadata after setup. The previous Road to Rome Anthology disc had newer assets than its old readme implied.

Internet lookup for exact Wine/1.61b installation compatibility yielded no useful expansion-specific evidence. General guide supplied by owner: https://steamcommunity.com/sharedfiles/filedetails/?id=2721068159 . Treat this as community guidance, not local verification. Primary local evidence is the owner's CD; retaining the base game's tested runner is a controlled local experiment rather than an asserted upstream fix.

## Install

From repository root:

```sh
games/battlefield-1942/install_secret_weapons.sh
```

Source: stopped official 1.61b `official161b/prefix-gameplay-verified` (no SiMPLE or Road to Rome). Destination: private ignored `local/runtime/battlefield-1942/secret-weapons/prefix`. Refuses existing destination, invalid/incorrect/writable media, symlinked prefix/output ancestors and active seed. Uses `scripts/common.sh` and the Road to Rome installer pattern; actual runner is lutris-GE-Proton7-43-x86_64 with sibling wineserver, inherited win32/XP setup. No added Wine DLL settings or host package changes. No automatic bundled DirectX/PunkBuster/tools installation. Owner handles any CD key directly in installer, never chat or scripts. Decline online registration/reboot. Only installed game-file hashes are recorded in before-install.json, not registry values.

Overrides: BF1942_SW_SEED, BF1942_SW_RUNTIME, BF1942_SW_CD, BF1942_SW_DEVICE, BF1942_WINE. Paths must be absolute; runtime must be Git-ignored. First safety test verified missing seed is rejected without output creation; script passes bash syntax checks. These are not installation/gameplay tests.

## Next gates

Physical-CD gameplay, stopped snapshots, backup integrity accounting, disk-free source launch and fresh/reused AppImage gameplay are now verified at the scopes described above. Backup remains sector-incomplete. The base-game original-install/official-patch automation gap described in README.md remains; this expansion recipe requires that prepared base seed.

## Disk-free preparation, launch and build

From repository root, after preserving the stopped physical-gameplay prefix:

```sh
BF1942_SIMPLE_SEED="$PWD/local/runtime/battlefield-1942/secret-weapons/prefix-gameplay-verified" \
BF1942_SIMPLE_RUNTIME="$PWD/local/runtime/battlefield-1942/secret-weapons-simple161b" \
games/battlefield-1942/prepare-simple.sh
games/battlefield-1942/launch_secret_weapons.sh
```

The generic prepare helper does not install expansion assets from its ZIP; those assets are already installed from CD 4 in the seed. `BF1942_SW_SIMPLE_RUNTIME` overrides the dedicated launcher runtime.

After confirmed disk-free gameplay, stop the matching wineserver before preserving `secret-weapons-simple161b/prefix-gameplay-verified`. Build with `games/battlefield-1942/extras/build_secret_weapons_appimage.sh`. The source recipe reuses common.sh and wine-appimage-builder.sh, has isolated AppDir/cache/output defaults, refuses an existing artifact and verifies the pinned patch payload before packaging.

Tested artifact:
`/home/test/danish-retro-game-launchers/local/runtime/battlefield-1942/secret-weapons-appimage-dist/Battlefield-1942-Secret-Weapons-1.61b-SiMPLE-x86_64.AppImage`

Writable state: `${XDG_DATA_HOME:-$HOME/.local/share}/battlefield-1942-secret-weapons-appimage`; override `BF1942_SW_APPIMAGE_STATE=/absolute/path`. Bundled runner and wineserver, +game XPack2, expansion assets, desktop/icon metadata and separate writable-state code were verified from the extracted final artifact. No CD image, CDEmu or VHBA requirement. Host FUSE and compatible Linux/32-bit graphics libraries are still needed; not a universal standalone claim.

Private licensed game bundle: do not distribute. Installer registry MAY include a CD key; its presence has not been audited, and no key was collected in chat. Base-game and Road to Rome packages were checksum-verified unchanged before the new build.
