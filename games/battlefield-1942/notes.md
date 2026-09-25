# Battlefield 1942 — WWII Anthology: indledende undersøgelse

Status: vanilla 1.6 er installeret og gameplay-bekræftet af ejeren med fysisk CD 1. Agenten har visuelt kontrolleret ejerens screenshot fra en indlæst bane med terræn, våben og HUD. Ejeren bekræftede også selv at have afsluttet normalt via Quit; processen returnerede 1, men dette er ikke alene bevis for crash. Lyd og langtidsstabilitet er ikke særskilt verificeret. Den afsluttede Wine-session er kontrolleret med paired wineserver -w, og prefixet er bevaret som `local/runtime/battlefield-1942/physical-vanilla-retry/prefix-gameplay-verified`. Kun `Mods/bf1942` er installeret; init.con angiver 1.6. CD 1-backup er startet; diskfri launch, 1.61b og AppImage er ikke testet. Slug: `battlefield-1942`.

## Igangværende originalinstallation

- Nyt privat prefix: `local/runtime/battlefield-1942/physical/prefix`, oprettet med `WINEARCH=win32` og projektets `local/runners/lutris-GE-Proton7-43-x86_64/bin/wine`.
- Runnerens faktiske `wine --version`: `wine-5.12-15762-ge9a47cbabb9 (Staging)`; sibling `wineserver --version`: `Wine 7.0`. Katalognavnet må ikke bruges som erstatning for disse aflæsninger. Ingen runnerfiler er ændret.
- `wineboot -i` gennemført, efterfulgt af afsluttet sibling `wineserver -w`. Windows-mode `winxp` skrevet og læst tilbage fra `HKCU\Software\Wine`.
- `dosdevices/d:` peger på `/run/media/test/DISC_1_BF1942_1`, `d::` på `/dev/sr0`; eksisterende links kontrolleret og erstattet uden at følge dem ind i CD-mappen. D: registreret som cdrom.
- Original startvej: CWD CD-roden; samme Wine kørt med `D:\Autorun.exe`, `WINEDEBUG=-all` og uden arvede `WINEARCH`, `WINEDLLOVERRIDES`, `WINEDLLPATH`. Efter start ventes på runnerens sibling wineserver.
- Autorun blev visuelt identificeret som WWII Anthology-menu. English valgt; efter menuanimation blev Install synlig og aktiveret. Original InstallShield viser nu Welcome-siden for Battlefield 1942. Dette er kun installer-start, ikke gennemført installation.
- Private screenshots/logs: `local/runtime/battlefield-1942/physical/logs/`. Ingen CD-kode er indtastet eller indsamlet. Ingen gamle DirectX-komponenter installeret.
- Handoff: ejeren fortsætter fra Welcome med Next, indtaster kun egen kode direkte i installerens kodefelt og afviser eventuel gammel DirectX/ekstra komponenter. Stop ved diskprompt og rapportér den ønskede disk, eller meld installation færdig før spiltest.
- Varigt installationsscript med validering/tests er endnu ikke implementeret; ovenstående beskriver den faktisk afprøvede startvej. Ingen af de senere faser er afsluttet.

## Verificeret lokalt

- Git havde eksisterende ændringer i hovedoversigten, Global Operations, Magnus & Myggen og scripts/iso-installer.sh samt flere untracked mapper. Intet var staged. Disse ændringer er ikke vores og må ikke medtages i et afsluttende Battlefield-commit.
- `/dev/sr0`: fysisk ASUS SDRW-08D2S-U via USB. ISO9660, volumenlabel `DISC_1_BF1942_1`, read-only mount `/run/media/test/DISC_1_BF1942_1`. `/dev/sr1` er CDEmu, ikke det fysiske drev.
- Autorun.inf: `open=AUTORUN.EXE`, visningsnavn Battlefield 1942 CD 1. Autorun.exe og Setup.exe er begge PE32/i386 Windows GUI-programmer. Setup.ini identificerer Battlefield 1942 og en flersproget installer. CAB-filer, setup.inx og ikernel.ex_ findes i roden: original Windows-installation, ikke en FlipOut-lignende direkte-CD-spilmappe. Autorun-menuens konkrete funktion er endnu ikke observeret visuelt. Ingen DOS- eller Win16-installationsvej påvist; alle binære payloads er endnu ikke klassificeret.
- CD indeholder både gammel v1.0-readme og `Support/English/UK/eReg/readme v1.6.txt`. Dette beviser ikke installeret version; aflæs den efter installation i `Mods/bf1942/init.con` og relevante binærmetadata.
- Original readme angiver Windows 98/ME/2000/XP (ikke 95), minimum 500 MHz CPU, 128 MB RAM, 32 MB HW-T&L-grafik med 24-bit z-buffer, 1.2 GB disk, 16x CD-ROM og DirectX 8.1-kompatibel lyd. Dette er grundspillets oprindelige krav, ikke et selvstændigt kravsæt for alle Anthology-udvidelser eller HD-mods.
- `SECDRV.SYS` og `DrvMgt.dll` findes på CD. PCGamingWiki beskriver retail SafeDisc 2. Kompatibilitetsrisiko, ikke en lokalt bevist blokering: afprøv original installation/fysisk CD før konklusion.
- `git check-ignore -v` bekræfter private paths under `local/sources/battlefield-1942`, `local/runtime/battlefield-1942` og `local/cache/battlefield-1942`. Brug builds under den ignorerede runtime; antag ikke at enhver mappe under local er ignoreret.

## Projektgenbrug

Læst: `scripts/common.sh`, `games/global-operations/launch_physical.sh`, Global Operations README og extras/build_appimage.sh samt `games/FlipOut/launch_folder.sh` og README.

Genbrug `retro_source_dir`, `retro_runtime_dir`, isoleret prefix, runnerens tilhørende wineserver, lås uden nedarvet descriptor og den fælles `scripts/wine-appimage-builder.sh`. Global Operations demonstrerer originalinstallation og optisk emulering; FlipOut demonstrerer originalfiler fra mappe uden noget monteret medie. Ingen af delene beviser samme resultat for BF1942. Overtag ikke Win98, bestemte grafikindstillinger eller CDEmu-krav. Global Operations-scriptets drive-link-logik skal ikke kopieres blindt: eksisterende directory-symlinks kræver sikker erstatning uden at følge dem ind på original-CD'en.

Foreløbig lokal testhypotese: isoleret prefix med Windows XP, fordi originalen udtrykkeligt understøtter XP. Runner og prefixarkitektur vælges først efter kontrol af tilgængelige runners; GE-Proton7-43 er en kandidat fra projektets InstallShield-erfaring, ikke en dokumenteret BF1942-løsning. Start uden ekstra DirectX, DXVK, dgVoodoo, Winetricks eller lydkomponenter.

## Kilder og dokumenterede forslag

- https://steamcommunity.com/sharedfiles/filedetails/?id=2721068159 — læst. WWII Anthology omfatter grundspillet, The Road to Rome og Secret Weapons of WWII. Guiden anbefaler official patches 1.6.19 og 1.61b, valgfri 4GB/LAA, community multiplayer, fonts, borderless og mods. Det er hovedsageligt en Windows-guide; anbefaling om antivirus-deaktivering, DirectPlay-feature og DirectX-installation overføres ikke til Wine. Dens komplette Moongamers-pakke bruges ikke som erstatning for ejerens originale CD'er.
- https://www.pcgamingwiki.com/wiki/Battlefield_1942 — retail SafeDisc 2; officielle patchlinks og versionskontrol. Origin 1.612 er en anden udgave og må ikke forveksles med retail 1.61b.
- https://community.pcgamingwiki.com/files/file/998-battlefield-1942-patch-1619-full/ — patchkandidat, ikke hentet eller afprøvet.
- https://community.pcgamingwiki.com/files/file/999-battlefield-1942-incremental-patch-1619-to-161b/ — patchkandidat, ikke hentet eller afprøvet. Verificér installeret udgangspunkt og sprog før brug; CD-readme antyder at 1.6 allerede kan være med.
- https://lutris.net/games/battlefield-1942/ — Wine-opskriften retter sig mod Moongamers-pakken, ikke denne originale Anthology-CD. Det er ikke bevis for fysisk-CD-kompatibilitet.
- https://github.com/Ahrkylien/BF1942-Master — serverimplementation i Python, ikke i sig selv en færdig klientpatch. Guidens link er derfor utilstrækkeligt til at vælge en klientpatch. Multiplayer kræver yderligere kildeundersøgelse.
- https://github.com/LANCommander/Borderless1942 — dokumenterer windowed-konfiguration og `+game XPack1` / `+game XPack2` til de to udvidelser. Windows/.NET-hjælper: behov og Wine-kompatibilitet skal vurderes før brug.
- https://ntcore.com/4gb-patch/ — LAA-kandidat fra guiden, ikke afprøvet. Ændrer executable og hører kun hjemme i separat, dokumenteret kompatibilitetsvariant med bevaret original.
- https://www.moddb.com/mods/high-definition-remaster — HD-kandidat fra guiden. Guiden advarer om øgede krav og konflikter mellem medfølgende ReShade/dgVoodoo og andre wrappers. Undersøg først teksturer uden wrapperpakken.
- https://www.moddb.com/mods/forgotten-hope og https://www.moddb.com/mods/desert-combat — mulige senere gameplay-mods fra guiden; ikke nødvendige for vanilla.

## Foreslået opdeling — ikke implementeret

1. Vanilla fra de originale CD'er, uden community-modifikationer. `launch.sh` er tiltænkt anbefalet indgang. Bevar den præcise CD-version som baseline.
2. Officielt opdateret vanilla, separat stoppet kopi, kun nødvendige officielle opdateringer til 1.61b.
3. The Road to Rome og Secret Weapons of WWII fra ejerens medier, separate startscript. Installér i separat Anthology-kopi, så grundspillets baseline forbliver uberørt.
4. Valgfri moderniseret variant: widescreen/læselige fonts og kun dokumenteret nødvendige kompatibilitetstiltag. Test grafikwrappers hver for sig, ikke stablet automatisk.
5. Valgfri multiplayer, HD og gameplay-mods som særskilte kopier/startscript efter vanilla-gate.

Hver variant skal have egen dokumenteret verifikation. En menu eller et installer-exit er ikke gameplay. Agentens visuelle kontrol, ejerens gameplay-bekræftelse og automatiske tests registreres særskilt. Installer-koder indtastes kun af ejeren direkte i originaldialogen; ingen screenshots af udfyldte kodefelter eller registry-dumps.

## Næste handling

Aftal variantomfang med ejeren; undersøg tilgængelig runner og åbn derefter originalens installation i et nyt privat prefix. Hav de øvrige Anthology-CD'er klar til konkrete diskprompts. TOC/backup, diskfri A/B/C-test, launcher-verifikation og AppImage følger først efter fysisk-CD-gameplay. Ét afsluttende fokuseret commit, ikke fasecommits; intet push. Ingen startkommando eller AppImage kan på nuværende tidspunkt betegnes som fungerende.
