# Private Battlefield Vietnam AppImage

Contains the user's installed commercial game and registration data. **Local/private only; never upload or distribute this artifact or its prefix.** No ISO/CD-ROM, CDEmu, or game-media mount is used.

Build from the user-confirmed stopped `simple121-ge7/prefix` with bundled `lutris-GE-Proton7-43-x86_64`:

```sh
games/battlefield-vietnam/extras/build_appimage.sh
```

This is a game-specific wrapper around `scripts/wine-appimage-builder.sh`. Output is `local/appimage-dist/Battlefield-Vietnam-1.21-SiMPLE-x86_64.AppImage`; intermediate files are in ignored `local/tmp/battlefield-vietnam-appimage` and `local/cache/battlefield-vietnam-appimage`. Optional `APPIMAGETOOL_BIN` can select an existing local appimagetool. Source runtime lock and matching wineserver stopped checks precede copying. Original executable icon is extracted with `wrestool`. Build dependencies are existing host Bash, Python/Pillow, Wine runner, wrestool and AppImage tooling; no system packages are installed by the wrapper.

Runtime copies the seed atomically into `${XDG_DATA_HOME:-$HOME/.local/share}/battlefield-vietnam-appimage/prefix`. It preserves that writable prefix on subsequent launches, locks through game/server exit, cleans old device mappings, and runs the bundled Wine and its sibling wineserver from the installed game's directory. No system Wine fallback or hardcoded developer runtime paths. Set `BFV_APPIMAGE_STATE` to an **absolute, new directory** for an isolated first run:

```sh
BFV_APPIMAGE_STATE="$HOME/.local/share/bfv-appimage-fresh-1" \
  ./local/appimage-dist/Battlefield-Vietnam-1.21-SiMPLE-x86_64.AppImage
```

If host FUSE is unavailable, AppImage's `--appimage-extract-and-run` may be used instead. The host still needs compatible 32/64-bit system/graphics/audio libraries and drivers; this is not a clean-host portability certification.

Synthetic checks (fake Wine executables, never gameplay):

```sh
python3 games/battlefield-vietnam/extras/test_appimage.py
bash -n games/battlefield-vietnam/extras/AppRun games/battlefield-vietnam/extras/build_appimage.sh
```

Verification performed: actual AppImage build and extraction, private registry equality by hashes only, SiMPLE payload manifest hashes, bundled runner executable hashes, original icon and desktop metadata, no bundled ISO, clean drive links, and runtime syntax. Synthetic runtime test covers bootstrap, cwd, argument forwarding, matched Wine/server, existing-state preservation, stale links, lock rejection, XDG default and invalid overrides. These build/content checks are separate from the real gameplay evidence below.

## Separate windowed variant (mouse fix confirmed; rebuilt artifact unplayed)

```sh
games/battlefield-vietnam/extras/build_appimage_windowed.sh
```

This thin wrapper calls `build_appimage.sh --windowed`, which uses the same
`scripts/wine-appimage-builder.sh`; it does not rebuild or replace the verified
fullscreen artifact. Defaults are separate:

- Artifact: `local/appimage-dist/Battlefield-Vietnam-1.21-SiMPLE-Windowed-x86_64.AppImage`
- AppDir: `local/tmp/battlefield-vietnam-windowed-appimage/BattlefieldVietnamWindowed.AppDir`
- Cache: `local/cache/battlefield-vietnam-windowed-appimage`
- Writable state: `${XDG_DATA_HOME:-$HOME/.local/share}/battlefield-vietnam-windowed-appimage`

The bundled `launch-mode` text file selects `windowed` or `fullscreen`; absence
preserves the original fullscreen launch behavior. Windowed runs the bundled Wine
with `explorer /desktop=BattlefieldVietnam,1024x768` followed by the game executable
and forwarded arguments. This uses a **1024×768 Wine virtual desktop**, containing
the game in a host window, rather than relying on a native game window flag. No
claim is made that native window flags are unsupported. Both modes retain the
same game working directory, matching bundled wineserver, state lock and server
wait lifecycle. `BFV_APPIMAGE_STATE` still overrides either default; use distinct
absolute directories to retain separation. Build-time `APPDIR`/`CACHE_DIR`
overrides should likewise remain distinct from fullscreen locations.

Windowed runtime additionally requires **host Python 3** (standard library only).
After the matching wineserver stopped-prefix check, and before starting Wine,
`normalize_windowed.py` corrects existing `Video.con` files in every real profile
directory under `Mods/BfVietnam/settings/Profiles` on **every windowed start**,
including both fresh seed copies and existing writable state. Only the display
width/height become `1024 768`; color depth, mode flags, other settings and line
endings remain intact. Before a change, the helper creates a sibling
`Video.con.before-window-resolution` exclusively, never overwriting an existing
backup. Directory-FD-relative, no-follow access prevents symlink traversal;
symlinked profile directories are skipped, symlinked path ancestors or Video.con
files abort launch, and backup symlinks are never followed. Atomic replacement
also avoids modifying an external hard-linked file. Fullscreen does not invoke
this helper or alter profile resolution. Missing profiles/files are left absent.

The initial windowed test had mismatched menu mouse coordinates: its Custom
profile retained `game.setGameDisplayMode 2560 1080 32 0` inside the 1024×768
virtual desktop. After that writable profile alone was backed up and changed to
`game.setGameDisplayMode 1024 768 32 0`, the user reported it "works really well".
This confirms the user-tested mouse fix, **not gameplay of the rebuilt file**.
The rebuild used the stopped `simple121-ge7` source, not the currently playing
state; the playing state was neither modified nor stopped during rebuilding.

Windowed rebuild verification:

- SHA-256: `b61dd0f4792bda4e41d72fcbae061d57983ef422787d77f996d1dd05450444de`.
- Previous experimental artifact preserved in ignored `local/appimage-dist/`
  as `Battlefield-Vietnam-1.21-SiMPLE-Windowed-before-mouse-fix-x86_64.AppImage`
  (SHA-256 `54e0b3b1e906cabb9bd6cfefcad3f28c4fef4b97f2d15031975f4b5a34e1710f`).
- Actual build/extraction passed: bundled helper and AppRun byte equality,
  launch-mode, shell syntax, desktop/icon metadata and source Custom Video.con
  equality. Extracted helper corrected a synthetic stale widescreen fixture.
- 3 source synthetic AppImage tests and 19 recipe tests passed; 2 packaged
  runtime/safety tests passed against the extracted AppRun/helper. Coverage
  includes stale widescreen seed, existing-state correction, immutable backup,
  fullscreen preservation, CRLF/settings preservation, stopped-prefix refusal,
  symlink and hardlink safety, state separation, locks and argument forwarding.
  The stale-resolution regression was observed failing before implementation.
- Fullscreen artifact remains unchanged with the SHA-256 recorded below.
- After rebuilding, the exact artifact was launched with fresh state at
  `local/runtime/battlefield-vietnam/windowed-final-fresh`. Asked about mouse,
  gameplay and sound, the user confirmed it worked really well. The process
  exited 0 and no processes belonging to that prefix remained afterward.
  Agent visual verification covered the earlier actual host window and intro,
  not gameplay of this final windowed artifact. Restart of this exact rebuilt
  artifact with existing state has not been manually verified; automated
  existing-state correction tests are separate evidence.
- Packaging emitted the existing optional AppStream metadata warning.

## Verified real artifact (fullscreen)

- Exact tested file: `/home/test/danish-retro-game-launchers/local/appimage-dist/Battlefield-Vietnam-1.21-SiMPLE-x86_64.AppImage`.
- SHA-256: `dc12b544f7c17c0a13d8f39b1b81d5b53ba3c96bc4bc44884a2f8cf51e173388`.
- The real file was launched with fresh writable state at `local/runtime/battlefield-vietnam/appimage-test-fresh`, then relaunched with that same existing state. The user confirmed both runs; latest confirmation covered movement, shooting, sound and menu exit. This is not a claim that the default state path was tested.
- Agent screenshot `gameplay-restart.png` shows first-person gameplay with gun, HUD and minimap. `/proc` inspection proved wine-preloader and wineserver came from the AppImage mount, not system Wine.
- Physical optical tray open (drive status 2), CDEmu empty, and no loop devices or mounted game images available during testing. Final cleanup confirmed no test-prefix processes, no Battlefield AppImage mount and no loop devices.
- Exit 1 was the user's confirmed normal game/menu exit, not a crash; no zero-exit claim is made.
- Automated evidence is separate: 19 recipe tests and 1 multi-case AppImage synthetic test passed. Fake-runtime assertions do not establish gameplay.

This is the separate third-party SiMPLE 1.21 installation, not the unchanged retail or official-only executable. [Main recipe](../README.md) documents original installation, the stopped preserved-prefix prerequisite, official patch sources/hashes, and the four SiMPLE replacement paths (EXE/DLL changed bytes; both `.con` files matched the source). All media and runtime evidence remain private. Other-host compatibility, online play and mods remain unverified.
