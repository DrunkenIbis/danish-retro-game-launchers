# Originalinstallation: igangværende, ikke gameplay-verificeret

Brug kun ejerens originale medier. Private filer ligger under projektets ignorerede `local/runtime/battlefield-1942/`. Den aktuelt afprøvede Wine-startvej og runneridentitet er i `notes.md`. Ingen færdig reproducerbar install.sh/launch.sh eller AppImage er endnu verificeret.

## CD 2: genbrug Battlefield Vietnams stale-mount-løsning

Observeret: InstallShield beder om disk 2 med `data3.cab`. `/dev/sr0` er det fysiske ASUS USB-drev. Den rå ISO9660-volume er `DISC_2_BF1942_2`, mens mountpoint stadig hedder `/run/media/test/DISC_1_BF1942_1` og dets rodliste fejlagtigt kun viser `DirectX81`. Den rå CD-rod indeholder `DATA3.CAB;1` på 585499804 bytes. Dette er en stale mount/directory-visning, ikke bevis for manglende CAB på originalen.

Bevar den åbne installation. Ingen tvungen unmount, genstart af Wine eller ændring af CD'en. Genbrug projektets eksisterende stagers direkte; de læser originalens ISO9660/Joliet-data uden det gamle mount og beskytter eksisterende destinationsfiler. Deres 19 regressionstests er kørt med succes før genbrug, inklusive partial/resume, symlinkede output-ancestors og afvisning af forkert disklabel.

Fra repository-roden, med CD 2 i det verificerede fysiske drev:

```sh
ROOT="$PWD"
OUT="$ROOT/local/runtime/battlefield-1942/install-media/disc2"
python3 games/battlefield-vietnam/stage-disc-cab.py \
  --device /dev/sr0 --label DISC_2_BF1942_2 --cab data3.cab \
  --output-dir "$OUT"
python3 games/battlefield-vietnam/stage-disc-directory.py \
  --device /dev/sr0 --label DISC_2_BF1942_2 --directory Support \
  --output-dir "$OUT" --manifest "$OUT/support-manifest.json"
python3 games/battlefield-vietnam/stage-disc-directory.py \
  --device /dev/sr0 --label DISC_2_BF1942_2 --directory eReg \
  --output-dir "$OUT" --manifest "$OUT/ereg-manifest.json"
```

Verificér enhed og label igen ved senere brug; `/dev/sr0` er ikke en universel konstant. Langsom optisk læsning må færdiggøres; behold CD og installer på plads. Disse kald er for en ny destination: overskriv ikke en bevaret kopi. Ved en afbrudt CAB-kopi kan `--resume` kontrollere eksisterende partial-bytes mod samme original før fortsættelse. En eksisterende færdig CAB skal bevares, ikke slettes for at genkøre kommandoen. Directory-helperen kan kontrollere eksisterende filer; vælg nyt manifestnavn ved gentagelse.

Hele Support- og eReg-træerne medtages for ikke at skulle hente én løs readme/registreringsfil ad gangen. Dette er originalfiler, ikke registry-eksport eller indsamling af CD-koden. Kopieringslog og manifests er private. Staging er IKKE en fuld CD-backup og ændrer ikke rækkefølgen for senere gameplay- og backup-gates.

Når alle kopieringer og hashkontroller er afsluttet, sættes installerens Path til den lokale disc2-rod via Wine Z:, ikke til selve CAB-filen eller dens Support-undermappe. I denne session er `dosdevices/z:` verificeret til `/`:

```text
Z:\home\test\danish-retro-game-launchers\local\runtime\battlefield-1942\install-media\disc2
```

Tryk derefter OK. Godkendelse af næste disk skal verificeres visuelt eller ved ejerens faktiske tilbagemelding. En verificeret filkopi betyder ikke, at installeren accepterede filen eller blev færdig. Ved en ny fil-/diskprompt beholdes dialogen åben til undersøgelse.

## Afbrydelse ved CD 3: rollback observeret

Ejeren nåede grundspillets Complete-side efter den lokale CD 2-staging. Derefter bad Anthology-forløbet om disk 3. Dens fysiske volumenlabel blev verificeret som `DISC_3_ROADTOROME`; roden indeholder separat Setup.exe og installations-CAB'er.

Agenten anbefalede Cancel/Yes for at stoppe før udvidelsen. Efter ejerens bekræftelse af afslutning og afsluttet paired wineserver viser kontrol imidlertid, at `Program Files/EA GAMES` er fjernet, og der findes ingen `BF1942.exe` noget sted under dette prefix' drive_c. De tidligere verificerede grundspilsfiler er altså ikke bevaret. Afbrydelsen rullede også grundspillet tilbage; Complete-siden var ikke et sikkert commit-punkt for hele Anthology-forløbet. Dette var en forkert anbefaling fra agenten.

Næste nødvendige trin: original CD 1, efterfulgt af ny originalinstallation med kontrolleret komponentvalg (kun grundspil) eller undersøgelse af den direkte Setup.exe-startvej. Bevar det nuværende prefix som diagnostisk tilstand og brug et nyt prefix til ny installation. Den verificerede private CD 2-staging bevares og kan genbruges. Anbefal ikke igen Cancel ved en efterfølgende komponentprompt under antagelse af, at grundspillet overlever.

## Nyt vanilla-forsøg

CD 1 er igen verificeret read-only på `/dev/sr0` med label `DISC_1_BF1942_1` og korrekt mount. Et nyt prefix er oprettet under `local/runtime/battlefield-1942/physical-vanilla-retry/prefix`; det gamle prefix er ikke ændret. Samme runner, win32 og winxp (læst tilbage), paired wineserver afsluttet efter bootstrap og konfiguration. D:/D:: peger på det verificerede mount/device.

Original `D:\Setup.exe` er startet direkte med CD-roden som arbejdsmappe, `WINEDEBUG=-all` og uden arvede DLL-overrides; ikke via Anthology Autorun. Visuelt verificeret: `Choose Setup Language`, English valgt. Komponenten skal kontrolleres visuelt før fortsættelse: kun grundspil, ingen udvidelser/PunkBuster/editor/SDK. Intet installations- eller gameplay-resultat er endnu verificeret for dette nye forsøg. Logs og screenshots er private under retry-runtime/logs.

## CD 2-staging-status (ikke installationsstatus)

Kopiering gennemført uden rapporterede læsefejl. `data3.cab`: 585499804 bytes, SHA-256 `9e348b4b2282be2eba3a3dc80cede59e3afe4ae97959697ca553fb8b1b1e9199`. Support: 84/84 filer; eReg: 3/3 filer. Efter kopiering er CAB-hash samt alle manifestførte filstørrelser og SHA-256 læst tilbage fra destinationen og kontrolleret. Z:-link peger fortsat på `/`. Klar til ovenstående Path-handoff. Installerens accept af disk 2 er endnu ikke verificeret. Originalinstallationen er fortsat ikke dokumenteret færdig, og gameplay er ikke testet. Ingen fuld CD-backup, diskfri launch eller AppImage påstås fungerende.
