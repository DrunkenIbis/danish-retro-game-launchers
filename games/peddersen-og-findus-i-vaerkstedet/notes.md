# Notes

The public recipe keeps only scripts and documentation. Runtime folders, ISOs, extracted discs, Wine prefixes, logs, screenshots and installed game assets are intentionally left out of Git.

## Disc inspection

Tested ISO:

- Source URL: `https://archive.org/download/peddersen-og-findus-i-vaerkstedet_202201/Peddersen%20og%20Findus%20i%20v%C3%A6rkstedet.iso`
- Local recipe filename: `Peddersen-og-Findus-i-vaerkstedet.iso`
- File type: ISO 9660 CD-ROM filesystem
- Volume label: `FINDUS1`
- SHA256 observed locally: `9d1d255889adf1ccd94252b04b31dba566258c4c682f605aea6fe12571d9d1c4`
- `autorun.inf`: `open=autorun\autorun.exe`
- `autorun/autorun.ini`: `install_path=..\Installér Findus1.exe`, registry key `HKEY_LOCAL_MACHINE\SOFTWARE\Gammafon\Findus1`
- `Installér Findus1.exe`: PE32 Windows GUI installer
- `DATA/Findus1.exe`: PE32 Windows GUI Macromedia Director 8.5 projector/main game
- `DATA/Indstillinger.exe`: PE32 settings utility
- `DATA/Xtras/*.x32`: Director Xtras including DirectOS/DirectSound/QT3Asset/etc.
- `Media/*.dxr` and `Media/Cast/*.cxt`: Director resources
- `Læs mig.txt`: version 2.0, Windows 95/98/NT4/2000/ME/XP, install copies parts of the game to hard disk to save in-game progress.

## Compatibility findings

Directly launching `D:\DATA\Findus1.exe` from an extracted/mapped CD is not enough. It reaches a Danish warning dialog saying `Findus1 skal installeres først.` The runtime must therefore provide installed state, not just a CD-ROM drive mapping.

The working path is a manual install under the private Wine prefix:

1. Copy `DATA/.` to `C:\Program Files\Findus1`.
2. Copy `Media/` beside the executable.
3. Add a lowercase `media -> Media` symlink because Director logs lowercase `media\start`/`media\gammafon` lookups on the case-sensitive host filesystem.
4. Write `HKLM\Software\Gammafon\Findus1` default value to `C:\Program Files\Findus1\Findus1.exe`.
5. Keep the extracted ISO mapped as `D:` with `.windows-label` = `FINDUS1`.
6. Use wine32/win32-prefix and Wine Windows version `win98`.
7. Launch inside a Wine Explorer virtual desktop at 800x600. The game content itself is 640x480.

## Verification evidence

Commands run from repo root during implementation:

- Downloaded ISO to `local/sources/peddersen-og-findus-i-vaerkstedet/Peddersen-og-Findus-i-vaerkstedet.iso` and verified SHA256 `9d1d255889adf1ccd94252b04b31dba566258c4c682f605aea6fe12571d9d1c4`.
- Extracted/listed ISO and verified autorun, installer, `DATA/Findus1.exe`, Xtras and `Media/` resources.
- Direct CD test with `D:\DATA\Findus1.exe` produced the blocker dialog `Findus1 skal installeres først.`
- Manual install + registry test launched `C:\Program Files\Findus1\Findus1.exe` and showed the `Peddersen og Findus i værkstedet` title screen.
- Keyboard input advanced from the title screen to an image-only farm overview.
- Mouse clicks advanced to an interactive farm/workshop gameplay scene with houses, cows/bird and visible UI buttons.
- AppImage build test created `extras/dist/peddersen-og-findus-i-vaerkstedet-x86_64.AppImage` at 558712000 bytes (about 533 MiB). Extracted AppImage metadata was verified: root `.desktop`, hicolor icon, `.DirIcon`, and `Icon=peddersen-og-findus-i-vaerkstedet` were present.
- AppImage smoke-test with a fresh `XDG_DATA_HOME` showed `/tmp/.mount_pedder...` in the process path, bundled Wine/wineserver from the AppImage mount, and `C:\Program Files\Findus1\Findus1.exe` running. The AppImage reached the title screen and then the same interactive farm/workshop scene after input.

This is treated as actual gameplay verification, not merely a process/window/splash test.

## Current blockers

No hard blocker found for the default repo-local wrapper on this machine.

Known caveat: `cmd /c vol d:` returned `Invalid function` with Wine's extracted-directory CD-ROM mapping even though `winepath d:\DATA\Findus1.exe` resolved correctly and the installed game worked. The recipe therefore does not rely on `vol d:` success as its final proof for this title; the decisive installed-state proof is the game advancing into gameplay.

Implementation pitfall found while testing this recipe: do not acquire a shell `flock` launch lock before `wineboot`/first-prefix initialization. Wine child processes can inherit the lock fd; if first-init leaves `wineboot`/`rundll32 setupapi` running after a timeout, the stale wineserver tree keeps the lock and the next actual launch reports that the game is already running. This launcher only acquires the lock immediately before starting a long-lived game/settings/setup process.

AppImage caveat: the bundled launch maps `FINDUS1_CDROM_DIR` directly to the read-only AppImage mount. `launch.sh` attempts to refresh `.windows-label`; inside the AppImage this prints a read-only filesystem warning, but the write is intentionally tolerated and gameplay still works. If a future Wine/CD-check path becomes stricter, the next best test is copying the small CD tree to writable state before launch, as some other recipes do.
