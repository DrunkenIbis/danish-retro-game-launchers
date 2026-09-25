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

## Verified real artifact

- Exact tested file: `/home/test/danish-retro-game-launchers/local/appimage-dist/Battlefield-Vietnam-1.21-SiMPLE-x86_64.AppImage`.
- SHA-256: `dc12b544f7c17c0a13d8f39b1b81d5b53ba3c96bc4bc44884a2f8cf51e173388`.
- The real file was launched with fresh writable state at `local/runtime/battlefield-vietnam/appimage-test-fresh`, then relaunched with that same existing state. The user confirmed both runs; latest confirmation covered movement, shooting, sound and menu exit. This is not a claim that the default state path was tested.
- Agent screenshot `gameplay-restart.png` shows first-person gameplay with gun, HUD and minimap. `/proc` inspection proved wine-preloader and wineserver came from the AppImage mount, not system Wine.
- Physical optical tray open (drive status 2), CDEmu empty, and no loop devices or mounted game images available during testing. Final cleanup confirmed no test-prefix processes, no Battlefield AppImage mount and no loop devices.
- Exit 1 was the user's confirmed normal game/menu exit, not a crash; no zero-exit claim is made.
- Automated evidence is separate: 19 recipe tests and 1 multi-case AppImage synthetic test passed. Fake-runtime assertions do not establish gameplay.

This is the separate third-party SiMPLE 1.21 installation, not the unchanged retail or official-only executable. [Main recipe](../README.md) documents original installation, the stopped preserved-prefix prerequisite, official patch sources/hashes, and the four SiMPLE replacement paths (EXE/DLL changed bytes; both `.con` files matched the source). All media and runtime evidence remain private. Other-host compatibility, online play and mods remain unverified.
