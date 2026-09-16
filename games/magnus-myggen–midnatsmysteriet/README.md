# Magnus & Myggen – Midnatsmysteriet

Status: Original installation from verified download completed; windowed intro/title visually verified. User reports that the game appears to run; interactive gameplay has not been independently verified. No AppImage built. Physical-CD workflow was skipped at the user's request because the CD appeared scratched; there is no CD/download comparison.

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

## Outstanding

The windowed launcher returned exit code 0. User reports: “spillet ser ud til at kører”. This is user-reported operation, not an independent playthrough or proof of in-game exit. Four isolated fake-runner tests pass (`python3 test_launcher.py`): 800×600 invocation and paired server wait; propagation of launch failure; missing installed EXE; missing CD data. Shell syntax also passes.

This checkpoint preserves the prepared-installation launcher and evidence, not a complete installer/AppImage pipeline. Independently verify interactive gameplay and in-game exit, add reproducible acquisition/setup scripts, then build and test the download-derived AppImage with bundled Wine and isolated XDG state. No portability claim is made. All media, prefixes, screenshots and helper binaries remain under ignored local directories.
