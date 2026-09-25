# SiMPLE community-patched variant (explicit owner request)

Status: separate official-1.61b-derived copy is user-confirmed into disk-free gameplay via `launch_simple.sh` (`launch.sh` alias). The private AppImage is also user-confirmed with fresh and reused writable state; bundled Wine and post-exit cleanup verified. See extras/README.md for limitations and exact verification scope. This is NOT the unmodified official release. Official 1.6 and 1.61b gameplay-confirmed seeds remain untouched.

## Provenance and scope

Requested forum: https://team-simple.org/forum/viewtopic.php?id=2369
Archive: https://team-simple.org/download/bf1942-v1.61-retail-patched.zip

Private download: `local/cache/battlefield-1942/simple/bf1942-v1.61-retail-patched.zip`, 1898301 bytes, SHA-256 `2b062f53fde1d6efdbc8c9e37521050ff9102c018d79c13ca56f0f762c8f7c21`. ZIP CRC check passed. Hash is a recorded download identity, not EA authentication.

Included simple.txt is dated 2014-05-21 and claims: No CD, Portable, Widescreen support, master.gamespy.com replaced with master.bf1942.sk. Thus this is more than a CD-only compatibility change. Current master-server operation has not been verified. Neither multiplayer nor widescreen behavior has been tested locally.

The actual archive has seven files (the old forum's prose count is inconsistent): BF1942.exe, simple.txt, Mods/bf1942/contentCrc32.con, Mods/bf1942/init.con, Mods/bf1942/Mod.dll, Mods/XPack1/Mod.dll, Mods/XPack2/Mod.dll. All seven were applied preserving hierarchy, as the supplied instructions require. XPack1/XPack2 DLLs alone do not install or validate expansion content; only the base game is installed.

## Reproduction

First obtain the owner-installed, official-1.61b-updated and stopped seed described in PATCHING.md. Place the above ZIP in the private cache, then from repository root:

```sh
games/battlefield-1942/prepare-simple.sh
games/battlefield-1942/launch_simple.sh
```

prepare-simple.sh uses scripts/common.sh, refuses an existing destination, validates the pinned archive hash/member set/CRC and requires seed version 1.61. It waits boundedly for the seed's paired wineserver before copying, writes only to a new runtime, applies patch files with read-back hashes, and removes copied optical mappings. Private before/after patch hashes are in `simple161b/logs/simple-patch-manifest.json`. This helper requires an already-installed seed; it is not yet the complete original-media installation pipeline.

Default seed: `local/runtime/battlefield-1942/official161b/prefix-gameplay-verified`.
Separate runtime: `local/runtime/battlefield-1942/simple161b`.
Overrides: BF1942_SIMPLE_SEED, BF1942_SIMPLE_RUNTIME, BF1942_SIMPLE_ARCHIVE, BF1942_WINE; shared RETRO_GAME_RUNTIME_DIR. Launcher debug override BF1942_DEBUG. Runner default is the previously tested project-local GE-Proton7-43; wineserver is selected only from its sibling directory. Correct game CWD, per-variant flock and server wait after game exit are applied. Logs stay private; no image mount or CDEmu operation is performed by this launcher.

## Verification so far

- Preparation completed and all seven destination files matched archive hashes.
- `bash -n` passed both shell scripts.
- Two automated negative tests passed: missing seed cannot create runtime; missing runtime cannot launch. These are not exhaustive safety tests or gameplay evidence.
- Before launch physical ASUS /dev/sr0 reported status 2 (open tray); CDEmu device 0 empty; no optical mounts.
- After launch Wine auto-discovered d::/e:: to empty /dev/sr0 and /dev/sr1. No CD-directory mappings; CDEmu still empty and no ISO9660/UDF mounts.
- User gameplay confirmation and a gameplay screenshot are pending. Do not infer success from a process or black/intro/menu window.

All game/patch/prefix/registration data remains private and ignored. No patch binaries are committed or intended for public redistribution.
