# Den Lyserøde Panter: Hokus Pokus Panter

Dansk Windows 95/98-era opskrift til Wanderlust Interactives "Den Lyserøde Panter: Hokus Pokus Panter" (1999).

Denne mappe indeholder kun opskriften: ingen spilfiler, ISO, udtrukket CD, Wine-prefix eller AppImage-builds må commit'es.

## Kilde

Reference/download:

- https://archive.org/download/Panter/Panter.iso
- ISO-volume label: `PANTER`
- Lokal verificeret SHA-256: `0d75bc8fe46df230d1fa38da70bf5c51f58d8f564904326fafa20a733ce45a55`

Brug kun filer du har ret til at bruge/distribuere.

## Installer/import

```sh
./games/den-lyseroede-panter-hokus-pokus-panter/install.sh --download --no-launch
```

Alternativt med en eksisterende ISO:

```sh
HPP_ISO=/sti/til/Panter.iso ./games/den-lyseroede-panter-hokus-pokus-panter/install.sh --existing --no-launch
```

Privat standardplacering:

```text
local/sources/den-lyseroede-panter-hokus-pokus-panter/Panter.iso
local/runtime/den-lyseroede-panter-hokus-pokus-panter/
```

## Status

- Installer: valideret mod den downloadede ISO; kræver `AUTORUN.INF`, `teaser.exe`, `setup.exe`, `INSTALL/Hpp.exe`, `INSTALL/HPP.BRO`, `INSTALL/HPP.HLP`, `INSTALL/SONGS.SON`, `hpp.orb`.
- Launcher: `launch.sh` udpakker ISO'en til `local/runtime/.../cdrom`, bygger en clean runtime-install under en win32 Wine-prefix, mapper CD'en som `PANTER`, sætter Wine til `win98` og starter `C:\HokusPokusPanter\Hpp.exe` i en 640x480 Wine desktop.
- AppImage: `extras/build_appimage.sh` bygger en Wine-bundlet AppDir/AppImage. AppImage-smoke-test viste `m.m. multimedia`/edugame splash i Wine desktop fra `/tmp/.mount_*` med `Hpp.exe` kørende.

## Teknisk note

ISO'en har `AUTORUN.INF` med `open=teaser.exe`, mens den egentlige spil-executable på CD'en er `INSTALL/Hpp.exe` (PE32). `setup.exe` og `INSTALL/HPPUNIN.EXE` er Win16/NE. Opskriften gætter derfor ikke på setup som standard-launcher; den forbereder en clean runtime fra `INSTALL/` og holder CD'en mappet som `PANTER`.

## Launch

```sh
./games/den-lyseroede-panter-hokus-pokus-panter/launch.sh
```

Nyttige modes:

```sh
HPP_MODE=prepare ./games/den-lyseroede-panter-hokus-pokus-panter/launch.sh
HPP_MODE=teaser  ./games/den-lyseroede-panter-hokus-pokus-panter/launch.sh
HPP_MODE=setup   ./games/den-lyseroede-panter-hokus-pokus-panter/launch.sh
HPP_MODE=kill    ./games/den-lyseroede-panter-hokus-pokus-panter/launch.sh
```
