# FlipOut! — virker direkte fra lokale spilfiler

## Verificeret status

- Original CD `FLIPOUT`: `/run/media/test/FLIPOUT`, verificeret read-only ISO9660 fra `/dev/sr0`.
- Windows-autorun er `FlipOut!.exe` (PE32); `install.bat` er den separate DOS-installationsvej. Der er ikke et almindeligt Windows `setup.exe` i CD-roden.
- `install.sh` genbruger `scripts/common.sh` og projektets private runtime-struktur. Kontrollerer korrekt medie/mount før initialisering.
- Separat win32-prefix med den eksisterende `lutris-GE-Proton7-43-x86_64` og Windows 98-indstilling, læst tilbage med Wine.
- Original autorun åbner og viser GameTek-intro samt efterfølgende animeret scene med rumvæsener og brikker. Dette er IKKE dokumentation for interaktivt gameplay; kan være intro/demo.
- Ingen CD-kode-dialog observeret endnu. Ingen kode indsamlet eller registreringsdata syntetiseret.
- Ejeren har bekræftet, at spillet virker perfekt med gameplay og styring fra fysisk CD, og har lukket spillet normalt. Visuelt agent-verificeret: intro og menu; interaktivt gameplay er brugerbekræftet.
- Det fungerende, afsluttede prefix er bevaret som `local/runtime/FlipOut-physical/prefix-physical-verified`.
- Lokal CD-backup: `local/sources/FlipOut/FLIPOUT.iso`, 248463360 bytes, SHA-256 `dfc327ec4c8afb4a47b89bd14f13da3b2ffff863d12b4f6577dba048d8b28e09`. Fysisk TOC: ét dataspor, LBA 0 til leadout 121320, ingen lydspor. Alle sektorer læst uden læsefejl; detaljer i privat `backup.json`.
- `7z t` tester alle 542 filer OK, men advarer om 612352 bytes efter ISO-filsystemets deklarerede slutning. Kopien bevarer disse bytes frem til fysisk leadout; de er ikke skåret fra.
- Ejeren har nu også bekræftet gameplay og styring fra ISO'en via CDEmu uden originaldisk.
- **Anbefalet kørsel: `launch_folder.sh`.** Ejeren har bekræftet perfekt gameplay og styring direkte fra de uændrede originalfiler i `local/runtime/FlipOut-folder/prefix/drive_c/FlipOut`, uden fysisk CD, monteret image eller CDEmu-medie. CDEmu blev aflæst som tomt, og der var ingen loop-enhed under testen. Agenten verificerede PLAY-/sprogdialogen visuelt; gameplay er brugerbekræftet. Normal afslutning med exitkode 0.
- Ingen spilprogrammer eller kopibeskyttelse er ændret. Ingen CD-kode-dialog blev vist.
- **AppImage: ikke bygget eller testet.** Der findes endnu ingen verificeret AppImage. Mappeversionen kræver ikke CDEmu/VHBA; dette må ikke forveksles med verificeret AppImage-portabilitet.
- Originaldisken er fjernet: Linux CDROM_DRIVE_STATUS rapporterer 2 (åben skuffe).
- Loop-mount-forsøget blev stoppet før Wine, fordi `/dev/loop0` ikke var læsbar for brugeren. Loop-enheden er fjernet. CDEmu fungerer med det allerede indlæste vhba-modul; ingen systemændringer var nødvendige. Dets medie/enhed bliver først mount-klar lidt efter `cdemu load`, så en senere launcher skal vente bounded på udev/mount.

## Anbefalet kørsel uden CD/image

```sh
./games/FlipOut/launch_folder.sh
```

Kræver det allerede forberedte private prefix under `local/runtime/FlipOut-folder/prefix` og de originale CD-filer kopieret til `drive_c/FlipOut`. Scriptet henter, kopierer eller installerer ikke automatisk spilfiler. `FLIPOUT_RUNTIME` og `FLIPOUT_WINE` kan overskrive standarderne. Start med PLAY i originaldialogen.

## Original fysisk-CD-vej

```sh
./games/FlipOut/install.sh check
./games/FlipOut/install.sh
```

Scriptet starter CD'ens originale Windows-autorun i Wine desktop. Installer ikke CD'ens gamle DirectX-pakke oven på Wine som standard. Eventuel CD-kode indtastes kun af ejeren i spillets eget vindue.

Miljøoverrides: `FLIPOUT_CD`, `FLIPOUT_DEVICE`, `FLIPOUT_RUNTIME`, `FLIPOUT_WINE`. Wine og wineserver skal komme fra samme runner. Standardprefix: `local/runtime/FlipOut-physical/prefix`; logs og billeder ligger under samme runtime. Prefix og alle spil-/registreringsdata er private og Git-ignorerede.

## Afhængigheder

Verificeret runner: projektets `local/runners/lutris-GE-Proton7-43-x86_64`, win32-prefix med Windows 98-indstilling. Mappeversionen kræver runnerens 32-bit system-/grafikbiblioteker, X11/XWayland, bash og `flock` fra util-linux. Fysisk-CD-scriptet kræver desuden Python 3, `findmnt`, `timeout` fra coreutils og læseadgang til optisk drev. Den afprøvede ISO-variant brugte værts-CDEmu/VHBA og udisksctl, men disse er **ikke nødvendige for den anbefalede mappeversion**. Ingen systempakker eller kernelmoduler blev ændret.

## Research

- https://www.myabandonware.com/game/flipout-7qs — identificerer Windows-udgaven som 1997, Gorilla Systems/GameTek; beskriver tile-flipping-puzzles og sværhedsgrader. Brugt som information, ikke som spilkilde.
- https://archive.org/details/flipout-pc — beskriver originaludgivelsen til MS-DOS og Windows 95. Ingen image hentet; den fysiske CD er kilden.

Der er ikke fundet en verificeret Wine-konfiguration i disse kilder. Valg af win32/Win98 er et lokalt kompatibilitetsforsøg baseret på Windows 95-udgaven, ikke et dokumenteret upstream-resultat.
