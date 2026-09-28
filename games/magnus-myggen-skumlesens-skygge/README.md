# Magnus & Myggen: Skumlesens Skygge

Status: **brugerbekræftet fungerende med fysisk original-CD**, inklusive gameplay, mus, lyd og lokal skrivebordsgenvej. Ingen AppImage eller automatisk frisk installation er bygget/verificeret.

## Én hoved-launcher, uden Lutris som krav

Fra repository-roden:

```sh
./games/magnus-myggen-skumlesens-skygge/launch.sh
```

Al startlogik er samlet i `launch.sh`: eget Wine-miljø, kontrol af original-CD og D:-mapping, eksklusiv prefixlås, kontrol af XP/grafikindstilling og selve spilstarten. Der er ingen test-timer eller debuglogfil. `launch_physical.sh` er kun et bagudkompatibelt alias til samme fil; skrivebordsgenvejen peger direkte på `launch.sh`.

Kontrol uden spilstart:

```sh
./games/magnus-myggen-skumlesens-skygge/launch.sh --check
```

`--check` starter kortvarige Wine-registerforespørgsler; det ændrer ikke indstillinger. `--desktop` tilføjer skrivebordsnotifikation ved fejl, når `notify-send` er tilgængelig.

## Forudsætninger

Dette er start af en **eksisterende lokal installation**, ikke en installer:

- Original-CD MM4DK monteret på `/run/media/test/MM4DK` fra `/dev/sr0`.
- Prefix `local/runtime/mm4-graphics/prefix`, inklusive den originale installerede `MM4.exe`.
- Den allerede brugerafprøvede private runner `local/runtime/mm4-thunk-fix/runner`.
- Win32/Windows XP, UseSystemMemory=0 og standardrenderer.
- Wine-desktop starter i **1024×768**; spillet vælger selv **800×600/16-bit**. Start direkte i 800×600 gav forkerte farver/layout.

Lutris, ISO-udpakning og download er ikke del af startvejen. Launcheren ændrer ikke CD-mapping eller registerindstillinger for at få en forkert opsætning til at bestå. Der er ingen skjult fallback til system-Wine eller et nyt prefix.

Den private runner har eksperimentelle LS01/DPMI-ændringer. Denne fungerende lokale kombination er bevaret; en urettet runner er endnu ikke verificeret med samme indstillinger. Game data, runtime, screenshots og logs følger ikke med repository'et. Et nyt checkout alene er derfor ikke spilklart.

## Genvej og dokumentation

- Lokal genvej: **Magnus & Myggen – Skumlesens Skygge (original-CD)** på skrivebordet og i programmenuen.
- [LOCAL_LAUNCHER.md](LOCAL_LAUNCHER.md): detaljer, kontroller og lokale stier.
- [notes.md](notes.md): verificerede resultater og begrænsninger.
- `recipe.yml`: aktuel original-CD-status og EXE-checksum.
- `lutris.yml`: valgfri lokal Linux-runner-konfiguration til samme `launch.sh`; importvejen er ikke GUI-testet.

## Tests

```sh
python3 games/magnus-myggen-skumlesens-skygge/test_launch_physical.py -v
bash -n games/magnus-myggen-skumlesens-skygge/launch.sh
desktop-file-validate games/magnus-myggen-skumlesens-skygge/skumlesens-skygge-original-cd.desktop
```

De automatiske tests bruger fixture-ejet Wine og medier, ikke den rigtige installation. Visuel kontrol og brugerbekræftelse af spillet er særskilte beviser, ikke udledt af unit-tests eller exitkode.

## Historik

Den tidligere `launch.sh` var en ikke-verificeret ISO-/manuel-installationsvej og er erstattet af den fungerende original-CD-start. Den findes fortsat i Git-historikken. Diagnosearbejde og fejlede ISO/CDEmu-/Win98-forsøg er ikke alternative godkendte startveje. Ingen spil-EXE-patch er nødvendig i den afprøvede opsætning.
