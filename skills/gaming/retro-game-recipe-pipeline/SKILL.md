---
name: retro-game-recipe-pipeline
description: Use when turning a retro game URL or disc image into a recipe-only repo entry with installer, launcher, and AppImage packaging, committing once after each verified phase.
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [retro-games, wine, dosbox, appimage, installers, recipe-repos]
    related_skills: [lutris-wine-iso-launchers, appimage-packaging, systematic-debugging]
---

# Retro Game Recipe Pipeline

## Overview

Use this workflow to convert a retro game source URL or physical-disc import into
three reliable repository artifacts:

1. `install.sh` — acquire/import media and validate it early.
2. `launch.sh` — prepare runtime state and launch the game correctly.
3. `extras/build_appimage.sh` — package the working runtime as an AppImage.

The key rule is one verified phase at a time, with one git commit after each
phase works. Do not build the AppImage until the launcher is proven. Do not build
the launcher until the installer can acquire or validate the correct media.

This repo is recipe-only. Never commit game data, ISO/BIN/CUE files, extracted
CDs, Wine prefixes, AppDirs, AppImages, logs, screenshots, or large runtime
artifacts. Those belong under ignored `local/sources/<game-id>/`,
`local/runtime/<game-id>/`, or external private folders.

## When to Use

Use when the user gives:

- a new retro-game URL, ISO, BIN/CUE, ZIP, or physical CD/DVD source
- a request to add installer + launcher + AppImage support
- a request to migrate an old working local folder into this recipe repo
- a request to make the workflow reusable across several games

Do not use for:

- modern native Linux games that do not need Wine/DOSBox/AppImage wrapping
- no-CD cracks, serials, executable patching to bypass copy protection, or
  distributing game data without rights
- purely cosmetic README edits that do not touch the recipe pipeline

## Hard Rules

1. **Three phases, three commits.**
   - Commit 1 after the installer works.
   - Commit 2 after the launcher works.
   - Commit 3 after the AppImage works.

2. **No phase skipping.**
   - A launcher that assumes private files beside the recipe is not good enough.
   - An AppImage that only works because host Wine/DOSBox was used is not proven.

3. **Validate early.**
   - Installer validation must catch wrong downloads, wrong discs, bad imports,
     or format mismatches before Wine/DOSBox starts.

4. **Act on actual evidence.**
   - Inspect image contents, `AUTORUN.INF`, executable types, and logs.
   - Do not guess the launcher path from filename alone.

5. **Keep the repo clean.**
   - Check `git status --short` before and after each phase.
   - Ensure generated media/build artifacts are ignored.

## Phase 0: Intake and Identification

Start by collecting:

- game title
- desired slug, usually lowercase Danish title without accents
- source URL(s): ISO, BIN/CUE, ZIP, archive page, etc.
- any known runner expectation: DOSBox, Wine, Win16, Windows 3.x, ScummVM
- whether the user wants a physical CD/DVD import path too

Create or update the game directory:

```text
games/<game-id>/
  README.md
  recipe.yml
  install.sh
  launch.sh
  lutris.yml
  notes.md
  extras/
    build_appimage.sh
```

Use ignored private paths:

```text
local/sources/<game-id>/
local/runtime/<game-id>/
local/logs/<game-id>/
```

Useful first inspection commands:

```sh
file <downloaded-file>
7z l -ba <image-or-archive> | sed -n '1,120p'
7z l -slt <image-or-archive> | sed -n '1,160p'
sed -n '1,80p' <cue-file>
```

For executables:

```sh
file cdrom/*.exe cdrom/*/*.exe 2>/dev/null | sort
```

Look for:

- `AUTORUN.INF` and `OPEN=`
- `SETUP.EXE`, `INSTALL.EXE`, `LAUNCHER.EXE`, final game EXE
- Inno Setup, InstallShield, Win16 NE, PE32, DOS MZ, DOS/4GW
- large resource files and split installer payloads (`setup-*.bin`, `DATA1.CAB`)

## Phase 1: Installer Script

Goal: `install.sh` can acquire/import media and validate required files.

Use the shared helper whenever possible:

```sh
source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
```

A minimal single-ISO installer:

```sh
#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="example-game"
GAME_TITLE="Example Game"
INSTALLER_DOWNLOAD_URL="https://example.invalid/Example.iso"
INSTALLER_DOWNLOAD_LABEL="archive.org reference-linket"
INSTALLER_ISO_NAME="Example.iso"
INSTALLER_ISO_ENV_VAR="EXAMPLE_ISO"
INSTALLER_SOURCE_DIR_ENV_VAR="EXAMPLE_SOURCE_DIR"
INSTALLER_CD_DEVICE_ENV_VAR="EXAMPLE_CD_DEVICE"
INSTALLER_REQUIRED_IMAGE_PATHS=(
  "GAME.EXE"
  "DATA/RESOURCE.DAT"
)

source "$REPO_ROOT/scripts/iso-installer.sh"
iso_installer_main "$@"
```

For multi-file media such as BIN/CUE:

```sh
INSTALLER_DOWNLOAD_FILES=(
  "game.bin|https://example.invalid/game.bin"
  "game.cue|https://example.invalid/game.cue"
)
INSTALLER_POST_ACQUIRE_HOOK="game_convert_bin_cue_to_iso"
```

Then implement the hook in the per-game `install.sh`. Keep it small and specific
to the media format. For MODE2/2352 BIN/CUE, convert each 2352-byte sector to a
2048-byte ISO payload using bytes `24..2071`. For MODE1/2352, inspect and use
the appropriate payload offset before copying from another game.

Installer verification:

```sh
bash -n scripts/iso-installer.sh games/<game-id>/install.sh
./games/<game-id>/install.sh --download --no-launch
./games/<game-id>/install.sh --existing --no-launch
```

Also test failure behavior:

```sh
# corrupt image should fail early
printf 'not an iso' > /tmp/bad.iso
./games/<game-id>/install.sh --existing --no-launch --iso /tmp/bad.iso

# wrong validation list should report missing files before launch
```

Commit after installer works:

```sh
git add scripts/iso-installer.sh games/<game-id>/install.sh games/<game-id>/README.md games/<game-id>/recipe.yml README.md docs/setup.md
git commit -m "feat(<game-id>): add installer flow" \
  -m "Add an installer that downloads/imports the game media and validates the files required by the launcher before Wine/DOSBox starts."
```

## Phase 2: Launcher Script

Goal: `launch.sh` can prepare runtime state and start the game from the repo's
standard private paths.

Launcher requirements:

- no stale hardcoded paths to old working folders
- source defaults under `${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}/<game-id>`
- runtime defaults under `${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}/<game-id>`
- environment overrides for source/image, runtime, prefix/config, mode, Wine/DOSBox
- `bash -n` clean
- bounded smoke test with real evidence

### Choose Runtime

Use DOSBox when:

- executables are DOS MZ, COM, BAT, DOS/4GW
- the game enters VGA/SVGA DOS modes
- a Windows installer is only a helper but the real game is DOS

Use Wine when:

- final executable is PE32 or Win16 NE
- installer is Inno/InstallShield/Win95/98-era
- DirectShow/Video-for-Windows/Director runtime is needed

Use Windows 3.x inside DOSBox when:

- the bundle contains a preinstalled Windows 3.x tree
- the game is a Win16 program intended to run under Windows 3.x

Treat ScummVM as diagnostic unless the game is known and complete there.

### Wine Launcher Pattern

A Wine launcher should normally:

1. extract or map the CD image into runtime `cdrom/`
2. initialize a Wine prefix only after choosing `WINEARCH`
3. install or manually prepare the game under `drive_c/`
4. map the extracted CD as a Wine drive
5. set label/registry details needed for CD checks
6. launch the final EXE in a virtual desktop when old graphics need it

Expose modes:

```sh
GAME_MODE=game ./launch.sh      # default
GAME_MODE=setup ./launch.sh     # visible setup
GAME_MODE=cdmenu ./launch.sh    # CD menu fallback
GAME_MODE=prepare ./launch.sh   # prepare runtime without opening a window
GAME_MODE=kill ./launch.sh      # stop prefix wineserver
```

For AppImage compatibility, `prepare` is important: it lets the AppImage builder
seed a working prefix without starting the game window.

### DOSBox Launcher Pattern

A DOSBox launcher should normally:

1. extract image/archive into runtime
2. create writable `game/` drive and read-only-ish `cdrom/` drive
3. generate runtime DOSBox config with absolute mounts
4. prefer `dosbox-staging`, then `dosbox`, then Flatpak DOSBox-Staging
5. tune audio for PipeWire when needed:
   - `rate = 48000`
   - `blocksize = 1024`
   - `prebuffer = 80`
   - `negotiate = false`

### Launcher Verification

Run syntax:

```sh
bash -n games/<game-id>/launch.sh
```

Run a bounded smoke test:

```sh
timeout 30s ./games/<game-id>/launch.sh 2>&1 | tee /tmp/<game-id>-launch.log
```

Then verify evidence:

- expected executable exists in runtime
- expected process starts (`pgrep -a wine`, `pgrep -a dosbox`)
- Wine log shows final EXE launched, not only setup/menu
- DOSBox log shows expected mounts and graphics/audio mode
- if timeout occurs, confirm it is because the game is still running
- kill/cleanup the prefix/process after tests

Commit after launcher works:

```sh
git add games/<game-id>/launch.sh games/<game-id>/lutris.yml games/<game-id>/README.md games/<game-id>/recipe.yml README.md
git commit -m "feat(<game-id>): add working launcher" \
  -m "Prepare runtime state from the validated media and launch the game through the selected Wine/DOSBox path."
```

## Phase 3: AppImage Packaging

Goal: `extras/build_appimage.sh` builds a verified AppDir/AppImage from the
working runtime.

### Wine AppImages

Use the shared helper:

```sh
source "$REPO_ROOT/scripts/wine-appimage-builder.sh"
wine_appimage_init_defaults
```

The per-game script should declare:

- `PROJECT_NAME`
- `DISPLAY_NAME`
- `APPDIR`, `DIST_DIR`, `CACHE_DIR`, `OUTPUT_APPIMAGE`
- source/runtime/prefix paths
- icon source (`.ico`, `.icn`, `.png`)
- a small internal AppImage launcher

The helper handles:

- Wine runtime copying
- ELF dependency collection via `ldd`
- dynamic loader copying
- AppRun and desktop metadata
- icon paths and `.DirIcon`
- appimagetool download/extraction
- AppDir verification

Wine AppImage launchers must copy mutable state out of the read-only AppImage,
usually under:

```text
~/.local/share/<game-id>/
```

Copy at least the Wine prefix on first run. If the launcher needs to write to the
CD-ROM tree (`.windows-label`, config, drive marker), copy CD-ROM data to state
too and map that writable copy.

Verify that the AppImage uses bundled Wine by checking process paths:

```sh
pgrep -a wine
# expect /tmp/.mount_<app>/usr/... or AppDir/usr/... during AppDir test
```

### DOSBox AppImages

Use the Det Magiske Jordbær pattern until a generic DOSBox helper exists. The
script should bundle:

- game runtime
- official DOSBox-Staging Linux x86_64 runtime
- resources next to the `dosbox` binary
- AppRun + desktop metadata + icons

Verify the log shows the bundled DOSBox version and the intended mixer/settings.

### AppImage Verification

Run:

```sh
bash -n games/<game-id>/extras/build_appimage.sh
./games/<game-id>/extras/build_appimage.sh --appdir-only
./games/<game-id>/extras/build_appimage.sh
```

Verify the built AppImage:

```sh
APP=games/<game-id>/extras/dist/<game-id>-x86_64.AppImage
file "$APP"
"$APP" --appimage-extract
cd squashfs-root
stat .DirIcon <game-id>.png <game-id>.desktop usr/share/applications/<game-id>.desktop usr/share/icons/hicolor/256x256/apps/<game-id>.png
grep '^Icon=' <game-id>.desktop usr/share/applications/<game-id>.desktop
file .DirIcon
cd .. && rm -rf squashfs-root
```

Smoke test:

```sh
timeout 35s "$APP" 2>&1 | tee /tmp/<game-id>-appimage.log
pgrep -a wine || pgrep -a dosbox || true
```

A timeout can be okay if the game remains running and logs/processes show the
right executable. A quick exit is not success unless the game is supposed to exit.

Commit after AppImage works:

```sh
git add scripts/wine-appimage-builder.sh games/<game-id>/extras/build_appimage.sh games/<game-id>/README.md README.md docs/setup.md
git commit -m "feat(<game-id>): add AppImage packaging" \
  -m "Package the prepared runtime into an AppDir/AppImage and verify desktop metadata, icons, bundled runtime, and launch behavior."
```

## Status Table

Update the root `README.md` progress table as phases land:

```text
| Game | Installer script | Launch script | AppImage script |
|---|---:|---:|---:|
| Example Game | ✅ | ✅ | — |
```

Only mark ✅ when the script exists and has been tested in its phase.

## Common Pitfalls

1. **Hardcoding old local paths.**
   Migrated wrappers often point at `/home/test/lutris_game_scripts_*`. Replace
   with repo-relative source/runtime defaults and environment overrides.

2. **Validating only one file.**
   `ADVENT.EXE` or `setup.exe` alone is often insufficient. Validate the files
   the launcher truly needs: resource files, split payloads, icons, config, etc.

3. **Treating `timeout` as success.**
   Timeout is only useful evidence when process/log state proves the game is
   still running correctly.

4. **Building AppImage from unprepared runtime.**
   Run installer and launcher prepare first. AppImage should package a known-good
   runtime, not an untested assumption.

5. **Using host Wine accidentally.**
   For self-contained Wine AppImages, inspect process paths. If the process is
   `/usr/bin/wine`, you have not proven bundling.

6. **Writing to the read-only AppImage mount.**
   Wine drive labels, prefixes, saves, and mutable CD marker files must live in
   `~/.local/share/<game-id>/`, not inside `/tmp/.mount_*`.

7. **Icon metadata mismatch.**
   AppImage icon path, root PNG, `.DirIcon`, desktop filename, and `Icon=` value
   must all use the same basename.

8. **Committing generated artifacts.**
   AppDirs, AppImages, prefixes, ISO/BIN/CUE files, extracted CD trees, logs, and
   screenshots must remain ignored.

9. **Providing no-CD patches.**
   Stay on compatibility: correct drive mapping, labels, registry, launch
   context, original media. Do not provide patch bytes or crack instructions.

## Verification Checklist

Before each phase commit:

- [ ] `git status --short` reviewed
- [ ] no generated media/runtime/build artifacts staged
- [ ] shell scripts pass `bash -n`
- [ ] installer validates correct media and rejects bad media
- [ ] launcher starts the intended executable or proves expected DOSBox state
- [ ] AppImage builds and extracts successfully
- [ ] AppImage desktop/icon metadata verified
- [ ] bundled Wine/DOSBox path verified where applicable
- [ ] root README status table updated
- [ ] one commit created for the completed phase only

## One-Line User Prompt Pattern

The user should be able to say:

```text
Kør retro-game pipeline for <Game Title>. URL'er: <url1> <url2> ...
```

Then execute:

1. Installer phase → test → commit.
2. Launcher phase → test → commit.
3. AppImage phase → test → commit.

If a phase fails, stop there, explain the blocker, and do not continue to the
next phase until the current one is fixed.
