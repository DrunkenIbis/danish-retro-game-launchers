# Magnus & Myggen – Midnatsmysteriet

Status: Download-derived AppImage built and user-confirmed playable: “det virker perfekt at spille via appimage”. Windowed 800×600 startup and bundled Wine verified. First isolated-state run exited 0. Physical-CD work was skipped at the user's request; no CD/download comparison or cross-machine portability verification.

## Verified source

Archive.org files:
- https://archive.org/download/magnus-myggen-midnatsmysteriet/MM12DK.bin
- https://archive.org/download/magnus-myggen-midnatsmysteriet/MM12DK.cue

Both files matched Archive.org SHA-1 metadata. Local private source directory: `local/sources/magnus-myggen-midnatsmysteriet/`.

SHA-256:
- BIN: `1929d6b599b4a81a9eea9f8e1d4da62ea103382762a1abc0c882caa2fc1f6980`
- CUE: `8f6c18cd38f39ba991e95c6076cad6163803ee6aae81d092195071c161357ef8`
- Derived ISO: `6db46b8961c75147b9187f0f062f9cde855729a78bd0868a9cb2aa77e737c593`

CUE specifies one MODE2/2352 track; data extraction used 2048 bytes at offset 24 per sector. Derived ISO label is MM12DK. The local converter also rewrote ISO volume-size fields; preserve this detail when reproducing the derived hash.

## Installation evidence

Private runtime: `local/runtime/magnus-myggen-midnatsmysteriet-download/`.

- System Wine 11 Staging win32 initialization hung in rundll32/setupapi before game setup. Its processes were stopped using that prefix's wineserver; the prefix directory was preserved.
- A new `prefix-ge-xp` was initialized successfully with the existing Wine-GE Proton 7-43 runner under `local/cache/mm3-physical-cd/runner/lutris-GE-Proton7-43-x86_64/`. No other game's installed prefix was reused.
- Wine compatibility was explicitly set to `winxp` under `HKCU\Software\Wine`, and read back. A prior `winecfg -v winxp` invocation did not establish this setting on the selected runner.
- Bootstrap used `WINEARCH=win32`, `WINEDLLOVERRIDES=mscoree,mshtml=` and the runner's lib/lib64 paths.
- D: points to this runtime's extracted `cdrom` directory; Wine drive type is cdrom.
- Original `D:\SETUP.EXE` was run directly from the CD directory. Default installation destination was accepted. No manual CAB installation, licence edits or executable patches were applied.
- Installer completion text was verified visually and through Windows controls. Screenshot: `installation-complete.png` in the private runtime.
- Installer's Finish action displayed a read-problem error and then SuperStarter. Direct launch of installed `mm13main.exe` from its own directory instead showed animated game graphics. This is startup evidence, not gameplay verification.

Installed executable:
`prefix-ge-xp/drive_c/Program Files/Magnus & Myggen - Midnatsmysteriet/mm13main.exe`

Do not confuse source volume MM12DK with the actual installed executable mm13main.exe. Do not use SuperStarter as proof of gameplay.

## Windowed launch

Run `./launch.sh` to use the prepared download installation in an 800×600 Wine desktop. The launcher uses the selected Wine-GE runner and its sibling wineserver; it does not rerun setup or modify licence state. `MIDNIGHT_RUNTIME` and `MIDNIGHT_RUNNER` can override the local runtime and runner directories; both overrides must be absolute paths.

The exact launcher passed `bash -n`. Its running window was visually checked: normal title bar, animated intro and title screen; the client screenshot is exactly 800×600 pixels. This verifies windowed startup, not interactive gameplay. Evidence: `window-800x600.png` and `window-frame.png` in the private runtime.

## AppImage — verified private build

Build with `./extras/build_appimage.sh` after closing the source game. Uses the repository's shared `scripts/wine-appimage-builder.sh` and the original installed download prefix. The source installation and CD data are preserved. Builder and source launcher share `local-copy.lock` to prevent concurrent launch during the snapshot.

Artifact: `extras/dist/magnus-myggen-midnatsmysteriet-x86_64.AppImage`
SHA-256: `4b58c8b3a55287599071debf196ebd5c4e4fede1d031ecbe55d9c58ee0cc2fd8`

Bundled resources: complete Wine-GE Proton 7-43 runner (including libraries/share data), original installed prefix, CD data and original icon. No game executable or licence-state patches. The reviewed lock fix affects source/build coordination, not the already tested AppImage contents.

Writable state: `${XDG_DATA_HOME:-$HOME/.local/share}/magnus-myggen-midnatsmysteriet/prefix`. AppRun atomically seeds the prefix on first run, preserves subsequent state and recreates D: for each current AppImage mount. It runs in an 800×600 Wine desktop with explicit bundled Wine and wineserver; no host Wine selection fallback.

Verification:
- Actual final AppImage launched with fresh isolated XDG data while external source and original runtime paths were reversibly renamed. Both were restored and verified after exit.
- No physical CD device or external image mount was present. Wine D: referenced the bundled CD; no alternative CD drive mappings were found.
- `/proc` executable paths pointed into `/tmp/.mount_.../usr/wine-ge/`, proving bundled Wine use.
- Intro/window visually inspected; user subsequently confirmed perfect gameplay via AppImage. These are distinct evidence sources.
- First AppImage test returned exit code 0. This alone does not prove in-game exit method.
- Finished artifact was independently extracted; AppRun syntax, original icon, desktop file and Wine executables checked.
- Five fake-runner launcher tests pass, including mutual exclusion with the builder; these are contract tests, not gameplay tests.

Remaining verification: repeat launch with existing user data, default-XDG launch, saved-game persistence and portability to other Linux systems. The bundle may still rely on host graphics/audio and system ABI libraries; bundled Wine on this host is not a universal portability guarantee. Automated source acquisition/original setup scripts are also not yet part of this recipe.

Private media, prefixes, screenshots and AppImages are excluded from Git. No push performed.
