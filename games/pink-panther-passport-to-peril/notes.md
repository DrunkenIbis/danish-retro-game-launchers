# Notes

Migrated from: `/home/test/lutris_game_scripts_Pink_panter`

The public recipe keeps only scripts and documentation. Runtime folders, ISOs, extracted discs, Wine prefixes, logs, screenshots, bundled runners and installed game assets are intentionally left out of Git.

## Disc inspection

Known Danish ISO:

- File/reference name: `PANTER.iso`
- Volume label: `PANTER`
- SHA256 observed locally: `b4ec3365a5066fbc840ec4d77c4b394258cb574f3621f9bfc976c497ec40d18d`
- `AUTORUN.INF`: `open=teaser.exe`
- `SETUP.EXE`: MS-DOS MZ / NE Windows 3.1 GUI installer
- `TEASER.EXE`: PE32 Windows 3.10 GUI teaser/autorun program
- `INSTALL/PPTP.EXE`: PE32 Windows 4.00 GUI main game executable

## Compatibility history

Directly launching `D:\\INSTALL\\PPTP.EXE` from the CD can fail because the `INSTALL/` directory also contains legacy Windows/Win32s system files. The working recipe uses a manual clean install that copies the game data but deliberately excludes those old system DLLs/drivers so Wine uses its own built-ins.

The launcher maps the extracted CD as `D:` with label `PANTER`, sets Wine's Windows version to `win98`, and uses a 640x480 Wine virtual desktop by default.

Smoke-test evidence from the migrated repo launcher:

- `PP_MODE=prepare` created the runtime install and omitted legacy system DLLs.
- A real launch started `C:\Program Files\Pink Panther\PPTP.EXE` under the `PinkPanther` Wine desktop.
- Screenshot evidence first showed the game's own Danish `Ændrer skærmopsætning` prompt with Pink Panther art.
- After choosing `Ja`, the window advanced to actual intro/game artwork (a dark scene with a child in a doorway), confirming it was not just a blank Wine desktop or launcher process.
