# The Road to Rome — separate original-media variant

Status: original CD 3 installation completed (installer exit 0 plus owner confirmation). Installed-file SHA-256 comparison: 58 added files, no changed or missing pre-existing game files. Base init.con still reports 1.61; XPack1 reports 1.6 and includes the six expansion map families and update archives. The shipped Anthology expansion content is newer than its historical v1.25 readme implies. Original installed shortcuts specify `BF1942.exe +game XPack1`. A stopped `prefix-installed` snapshot is preserved. Owner confirmed physical-CD expansion gameplay ('det virker godt'), then confirmed everything worked as intended and authorized continuing. This is owner verification, not an agent gameplay screenshot. After paired wineserver completed, `prefix-gameplay-verified` was preserved. Disc-free expansion gameplay is now owner-confirmed through `launch_road_to_rome.sh`, using the same pinned SiMPLE archive in separate `road-to-rome-simple161b`. Physical status was 2 (tray open), CDEmu empty, no external media mounts before and after startup; Wine re-created only links to the empty optical devices. All 23 original XPack1 archive files were SHA-256 compared and preserved. The stopped disk-free prefix is saved as `road-to-rome-simple161b/prefix-gameplay-verified`. Its exact AppImage is now owner-confirmed into expansion gameplay with both fresh and reused writable state. This is user verification, not an agent gameplay screenshot.

Backup completed as an INCOMPLETE rescue copy using `backup-disc.sh DISC_3_ROADTOROME`: physical TOC verified one Mode 1 data track starting at LBA 0, leadout LBA 206794, no CD-audio tracks. Source `/dev/sr0`; destination private `local/sources/battlefield-1942/backups/DISC_3_ROADTOROME.iso`. Actual/expected size 423514112 bytes; SHA-256 `2de90a53cde41d1f122134208355a8cf0b6c36911fa1faec59dd4f84595aaaf8`. ddrescue exit 0 does not mean complete: map bytes by status: + 405200896, - 106496, * 651264, ? 17301504, / 253952. All-data-sector coverage is false; raw/subchannel/protection data is not preserved. Original disc was only read. Follow-up `audit-rescue-iso.py` checked 453 file/directory/path-table records across primary/Joliet trees with zero affected records, and `7z t` returned 0. This establishes filesystem read coverage and archive readability, NOT complete sector backup or game acceptance of the image. The common game backup script now accepts this exact expansion label; the regression test first failed at label rejection and then passed after adding support.

## Isolation / entry point

Run from repository root:

```sh
games/battlefield-1942/install_road_to_rome.sh
```

This refuses an existing output runtime. Default source is the stopped official 1.61b seed, NOT the community-patched installation. Default output: ignored `local/runtime/battlefield-1942/road-to-rome/prefix`. The source launcher and existing SiMPLE AppImage remain untouched. Dedicated disk-free launcher: `launch_road_to_rome.sh`. Recreate the SiMPLE copy after the original expansion installation and a stopped-prefix preservation step with:

```sh
BF1942_SIMPLE_SEED="$PWD/local/runtime/battlefield-1942/road-to-rome/prefix-gameplay-verified" \
BF1942_SIMPLE_RUNTIME="$PWD/local/runtime/battlefield-1942/road-to-rome-simple161b" \
games/battlefield-1942/prepare-simple.sh
```

The generic prepare helper's printed warning that expansion data is not installed means the ZIP does not supply it; this variant already has the original XPack1 archives from CD 3. Build from the stopped, gameplay-confirmed SiMPLE seed with `games/battlefield-1942/extras/build_road_to_rome_appimage.sh`. The dedicated builder reuses `scripts/wine-appimage-builder.sh`, bundles the same runner and XPack1 assets, and uses `extras/AppRun.road-to-rome`. Output: `local/runtime/battlefield-1942/road-to-rome-appimage-dist/Battlefield-1942-Road-to-Rome-1.61b-SiMPLE-x86_64.AppImage`. State: `${XDG_DATA_HOME:-$HOME/.local/share}/battlefield-1942-road-to-rome-appimage`, override `BF1942_RTR_APPIMAGE_STATE`. No ISO or CDEmu requirement. Licensed files included; installer registry MAY contain CD keys (presence not audited). Private use only.

Build and exact artifact SHA-256/extraction checks passed. Extracted AppRun selects +game XPack1 and the separate writable state; Wine/wineserver, expansion assets, matching desktop/icon assets are present. Both artifact runs were separately confirmed by the owner. On repeat start, /proc verified Wine preloader and matching wineserver from the exact AppImage mount. After each run, the exact prefix had no remaining processes and its recorded AppImage mount was gone. Both returned 1; user reported good gameplay, but Quit intent was not separately stated for these two runs. Audio was not independently measured. Physical CD and CDEmu were empty; no external game image was mounted. Base and expansion artifact SHA-256 checks still pass. Cross-machine portability, multiplayer and long-term stability remain unverified.

Secret Weapons and graphics enhancements will have their own separately tested runtimes/scripts/artifacts.

Overrides: BF1942_RTR_SEED, BF1942_RTR_RUNTIME, BF1942_RTR_CD, BF1942_RTR_DEVICE and BF1942_WINE. All paths absolute, output must be ignored by Git. Default runner is lutris-GE-Proton7-43-x86_64 (reports `wine-5.12-15762-ge9a47cbabb9 (Staging)`), with its paired wineserver. It inherits the already verified win32/XP base prefix; no new DLL overrides, DirectX packages or system changes. Script queries Windows mode into private logs. Per-game installed-file hashes before setup are saved privately; registry contents/CD codes are not printed.

## Media findings

Physical ASUS drive `/dev/sr0`, ISO9660 label `DISC_3_ROADTOROME`, mounted read-only at `/run/media/test/DISC_3_ROADTOROME`. Canonical mount source, label and product name are checked again by the installer script. `Setup.exe` is PE32 Intel i386 Windows GUI, not DOS/Win16. No autorun.inf observed in root; this expansion disc has its own Setup.exe and InstallShield cabinets. Setup.ini names `Battlefield 1942: The Road To Rome`.

Original `Support/English UK/eReg/readme.txt` (English US agrees) identifies Road to Rome v1.25 and describes its bundled older patch. Requirements include Windows 98/ME/2000/XP, DirectX 8.1-compatible hardware, HW T&L, and additional expansion disk space. This is historical documentation, not a reason to install CD DirectX into Wine. The readme requires a later EA patch for multiplayer; current online service availability is not established.

Local experiment: install expansion over a COPY of the clean official 1.61b seed, inspect changed file hashes/version/expansion assets afterwards, and apply the appropriate official patch chain if necessary. Do not assume older expansion setup preserves new files, and do not layer SiMPLE until the original expansion installation is verified.

## Sources / evidence limits

- User's original physical CD and readme/Setup.ini above are primary edition-specific sources.
- https://steamcommunity.com/sharedfiles/filedetails/?id=2721068159 — user's general community guide; not proof that this original-disc installation works.
- https://community.pcgamingwiki.com/files/file/998-battlefield-1942-patch-1619-full/ — full 1.6.19 patch listing; search result indicates no prior patch required. Not downloaded/applied for this variant yet.
- https://team-simple.org/forum/viewtopic.php?id=3875 — search result describes another user's expansion-before-full-1.619-then-1.61b order. Anecdotal, not validation of this Anthology edition.

Installer CD-key prompts must be handled by the owner directly, never in chat/scripts/logs. Decline old bundled DirectX, online registration and reboot. Do not cancel a chained installer merely because one component says Complete: earlier Anthology cancellation rolled the installation back.

## Remaining gates

Original expansion setup, installed-file audit, physical-CD gameplay, stopped reference copies, honest rescue-backup audit, disk-free launcher and fresh/reused AppImage gameplay gates are complete at the evidence levels above. Backup is still sector-incomplete. Full recreation from a clean checkout still depends on the base-game original-install/official-patch steps documented in the main game README; this expansion does not close that pre-existing automation gap. Secret Weapons and graphics additions have not started.
