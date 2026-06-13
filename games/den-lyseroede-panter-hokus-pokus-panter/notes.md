# Noter: Den Lyserøde Panter: Hokus Pokus Panter

## Disc-inspektion

Kommandoer kørt på `local/sources/den-lyseroede-panter-hokus-pokus-panter/Panter.iso`:

```sh
file Panter.iso
sha256sum Panter.iso
7z l -ba Panter.iso
```

Resultat:

- `file`: ISO 9660 CD-ROM filesystem data `PANTER`
- SHA-256: `0d75bc8fe46df230d1fa38da70bf5c51f58d8f564904326fafa20a733ce45a55`
- `AUTORUN.INF`:

```ini
[autorun]
open=teaser.exe
icon=install\CD.ico
```

Relevante executables:

```text
setup.exe                 Win16 NE GUI installer
teaser.exe                PE32 Win32 GUI autorun/teaser
INSTALL/Hpp.exe           PE32 Win32 GUI game executable
INSTALL/HPPUNIN.EXE       Win16 NE GUI uninstaller
```

## Wine-kompatibilitet

Dette ligner den tidligere Pink Panther: Passport to Peril-recipe: CD'en indeholder gamle Win32s/system-DLL'er under `INSTALL/`, og spillet startes bedst fra en clean runtime/install-kopi, hvor gamle system-DLL'er ikke shadow'er Wine's egne DLL'er. `setup.exe` er Win16/NE og er ikke default-launcher.

`INSTALL/Hpp.exe` har en PE-header, hvor `SizeOfImage` er mindre end den sidste `.rsrc`-sektions virtuelle ende:

```text
SizeOfImage: 0xb3000
.rsrc end:   0xb83d4
aligned:     0xb9000
```

Wine 11 afviser den originale executable med `wine: failed to start ... c000007b` og `section .rsrc too large`. Wrapperen patcher kun den private runtime-kopi (`drive_c/HokusPokusPanter/Hpp.exe`) fra `0xb3000` til `0xb9000`; ISO'en røres ikke, og patchen er ikke en CD-check/no-CD patch.

## Verifikation

Kørt:

```sh
bash -n games/den-lyseroede-panter-hokus-pokus-panter/launch.sh
HPP_DRY_RUN=1 ./games/den-lyseroede-panter-hokus-pokus-panter/launch.sh
HPP_MODE=prepare ./games/den-lyseroede-panter-hokus-pokus-panter/launch.sh
```

Prepare byggede runtime, udelod gamle system-DLL'er og patcherede `Hpp.exe SizeOfImage: 0xb3000 -> 0xb9000`.

Smoke-test:

- `HPP_MODE=game ./launch.sh` starter Wine desktop `HokusPokusPanter - Wine Desktop` i 640x480.
- Processer under test: `explorer.exe /desktop=HokusPokusPanter,640x480 C:\HokusPokusPanter\Hpp.exe` og `C:\HokusPokusPanter\Hpp.exe`.
- Screenshot `/tmp/hokus-pokus-panter-window.png`: MGM/UA splash, ikke blank Wine desktop.
- Screenshot `/tmp/hokus-pokus-panter-window-2.png`: intro-scene i tandlægehuset.
- Screenshot `/tmp/hokus-pokus-panter-window-6.png`: synlig spil/intro-scene med Pink Panther og tandlægefiguren; ingen licens-/CD-fejl eller modal stop observeret.

AppImage-test:

- `extras/build_appimage.sh --appdir-only` byggede AppDir og metadata/icon validerede.
- `extras/build_appimage.sh` byggede `extras/dist/den-lyseroede-panter-hokus-pokus-panter-x86_64.AppImage` (747M lokalt build-output, ignoreret af Git).
- AppImage smoke-test fra frisk state startede processer fra `/tmp/.mount_den-ly...`, inkl. bundled `wineserver`, `explorer.exe /desktop=HokusPokusPanter,640x480 C:\HokusPokusPanter\Hpp.exe` og `C:\HokusPokusPanter\Hpp.exe`.
- Screenshot `/tmp/hpp-appimage-window4.png`: `m.m. multimedia`/`edugame` splash i 640x480 Wine desktop; ikke blankt vindue.
- Første AppImage-forsøg uden seed-prefix blev fanget i Wine first-run setup; final builder pakker derfor en seed-prefix uden `C:\HokusPokusPanter`, hvorefter `launch.sh` installerer spilkopien fra den mountede CD-ROM på første run.

Manuel, længere playthrough/interaktiv klik-test er ikke fuldt verificeret endnu; status er derfor markeret som "starter og viser spilscene" frem for endeligt fuldt gennemspillet.
