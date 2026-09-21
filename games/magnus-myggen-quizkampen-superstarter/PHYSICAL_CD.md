# Original fysisk CD: Q112DK

Denne gren er adskilt fra den historiske Q122DK SuperStarter-ISO og dens
manuelt udpakkede runtime. Den gamle licensdiagnose er ikke verificeret for Q112DK.

## Start den eksisterende originalinstallation

```sh
./games/magnus-myggen-quizkampen-superstarter/launch_physical.sh
```

CD'en skal være monteret på `/run/media/$USER/Q112DK`, normalt fra `/dev/sr0`.
Launcheren kræver den allerede gennemførte originalinstallation og downloader,
udpakker, geninstallerer eller ændrer ikke CD/registrering. Den bruger Wine-GE
7-43 og et 800×600 Wine-desktopvindue; den gamle `launch.sh` er uændret.

Private standardstier under repoets `local/`:

- Runner: `runners/lutris-GE-Proton7-43-x86_64`
- Runtime: `runtime/magnus-myggen-quizkampen-superstarter/physical-q112dk-ge`
- Prefix: `<runtime>/wineprefix32`
- Installeret EXE: `C:\Program Files\Magnus & Myggen - Quizkampen\mm12main.EXE`
- Log: `<runtime>/logs/physical-launch.log`

Overrides: `MMQ_PHYSICAL_RUNTIME`, `MMQ_PHYSICAL_RUNNER`, `MMQ_PHYSICAL_CD`,
`MMQ_PHYSICAL_DEVICE`. Prefixets eksisterende `d:` og `d::` skal pege på samme
mountpoint og enhed; launcheren afviser forkerte mappings frem for at ændre dem.
`launch_physical.sh dry-run` viser opsætningen uden ændringer.

## Installationens proveniens

Original `D:\setup.exe` fra den læsbare, read-only Q112DK-CD blev kørt i et nyt
win32-prefix med Wine-GE 7-43, Windows 98 og `WINEDLLOVERRIDES=mscoree,mshtml=`.
Brugeren gennemførte den grafiske installation. Wine D: peger på mountpointet,
D:: på `/dev/sr0`, og Wine Drives `d:` er `cdrom`. Ingen gamle manuelt udpakkede
spilfiler, binære patches eller konstruerede licensværdier blev overført.

Systemets Wine 11 hang under bootstrap i et separat prefix `physical-q112dk`;
det er bevaret som fejlet forsøg og bruges ikke af denne launcher.

## Verifikationsniveau og begrænsninger

- Original installation gennemført; installeret EXE fundet.
- Direkte start nåede spiller-/spilmenuen, visuelt verificeret. Ingen gammel
  SuperStarter-modal observeret i den test.
- Direkte fuldskærm gav et 3840×1080 vindue med menuen i et 800×600 hjørne;
  brugeren rapporterede manglende reaktion på klik.
- Wine-desktop på 800×600 blev visuelt verificeret. Brugeren rapporterede
  derefter, at spillet så ud til at køre. Dette er ikke en fuld gameplay-test.
- Efterfølgende bekræftede brugeren, at CD-fri drift og den færdige AppImage
  fungerer rigtig godt; se Q112DK_APPIMAGE.md for den aktuelle status.
- Q112DK-AppImage/CD-fri drift er brugerbekræftet; tidligere Q122DK-AppImage må ikke
  præsenteres som en pakning af denne installation.

Tests: `python3 games/magnus-myggen-quizkampen-superstarter/test_physical.py`.
Kun opskrift, tests og dokumentation hører til i Git, ikke CD eller Wine-prefix.
