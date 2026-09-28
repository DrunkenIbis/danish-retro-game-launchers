# Lokal startgenvej – original-CD

Al startlogik er nu samlet i `launch.sh`, som starter den lokale brugerafprøvede opsætning uden Lutris. `launch_physical.sh` er kun et bagudkompatibelt alias. Den tidligere ISO-launcher er erstattet og findes i Git-historikken; den fungerende runtime er uændret.

## Brug

Vælg **Magnus & Myggen – Skumlesens Skygge (original-CD)** i programmenuen eller brug `skumlesens-skygge-original-cd.desktop` på skrivebordet.

Original-CD'en skal sidde i drevet og være monteret på `/run/media/test/MM4DK` fra `/dev/sr0`. Åbn den i filhåndteringen, hvis den ikke er monteret. Launcheren monterer, udskubber eller ændrer ikke CD'en.

Direkte fra terminal:

```sh
/home/test/danish-retro-game-launchers/games/magnus-myggen-skumlesens-skygge/launch.sh
```

Kontrollér forudsætningerne uden at starte spillet:

```sh
/home/test/danish-retro-game-launchers/games/magnus-myggen-skumlesens-skygge/launch.sh --check
```

`--check` starter Wine-registerforespørgsler og lukker sin egen Wine-session igen. Den installerer ikke noget og ændrer ikke spillets indstillinger. Ved `--desktop` vises fejl desuden som skrivebordsnotifikation, hvis `notify-send` er tilgængelig.

## Fastholdt opsætning

- Prefix: `local/runtime/mm4-graphics/prefix`.
- Runner: `local/runtime/mm4-thunk-fix/runner` (den brugerafprøvede private runner; dens LS01/DPMI-ændringer er fortsat eksperimentelle).
- Win32, Windows XP, UseSystemMemory=0; disse registerværdier aflæses, ikke overskrives.
- Startskrivebord: 1024×768. Spillet skifter selv til 800×600/16-bit. Brug ikke 800×600 som startstørrelse: se `notes.md`.
- Samme originale MM4.exe, arbejdsmappe og D:/D::-mapping som den manuelle test.
- Ingen test-timer omkring spillet, WINEDEBUG=-all, ingen debuglogfil. Tidsgrænser gælder kun korte register-/serverkontroller og cleanup.
- Fælles lås med diagnosescriptet forhindrer to samtidige starter. En allerede kørende Wine-session afvises uden at dræbe den.
- Efter egen kørsel stoppes kun dette prefix via dets parrede wineserver, som i den brugerafprøvede manuelle kommando.

Dette er en genvej til en eksisterende lokal installation, ikke en geninstallationsopskrift, ren upstream-runner eller AppImage. Den fungerende runtime er ikke udskiftet eller kopieret. Hvis projektet flyttes, skal Exec og TryExec i `.desktop`-kilden opdateres og genvejene geninstalleres.

## Genvejskilde og installation

Kilde: `skumlesens-skygge-original-cd.desktop` i denne mappe. Lokale kopier:

- `/home/test/.local/share/applications/skumlesens-skygge-original-cd.desktop`
- `/home/test/Skrivebord/skumlesens-skygge-original-cd.desktop`

Begge er kopier af kilden og eksekverbare; skrivebordskopien har GIO `metadata::trusted=true`. Den eksisterende Hævn-genvej er ikke ændret. Ikonet er systemets generiske spilikon.

## Kontroller

- `bash -n launch.sh` og `desktop-file-validate skumlesens-skygge-original-cd.desktop` består.
- `python3 test_launch_physical.py -v`: elleve isolerede tests består. De bruger egne Wine-/mount-fixtures, ikke den rigtige installation. Dækker korrekt miljø/skrivebord/arbejdsmappe, `--check`, manglende CD, forkert mount/mapping, lås, ændret Windows-mode og fejlretur med prefix-afgrænset cleanup, aktiv wineserver uden kill, bagudkompatibelt alias og afvisning af en ikke-nul registerværdi med foranstillet nul.
- Reel `launch.sh --check`: exit 0, original-CD, XP og UseSystemMemory=0 kontrolleret.
- Den installerede skrivebordsgenvej er kørt gennem GIO DesktopAppInfo med child-PID-sporing. Visuelt verificeret intro og den læsbare menu med Nyt spil/Hent spil/Afslut spil: `local/runtime/mm4-graphics/logs/shortcut-start-27262979.png` og `shortcut-book-27262979.png`. Spillet blev efterladt åbent ved menuen til brugeren. Dette verificerede genvejens startvej. Brugeren afprøvede derefter selv kørslen via den nye genvej og bekræftede: “det fungerede perfekt”. Kørslen afsluttede med exitkode 0. Efter samling i `launch.sh` blev også den opdaterede genvej brugerafprøvet: “det fungerede perfekt”, normal exit 0. Fuld gennemspilning er ikke særskilt bekræftet.
- Almindelig gameplay, mus og lyd i denne runtime er tidligere brugerbekræftet; se `notes.md`. Gem/hent og fuld gennemspilning er ikke særskilt godkendt.

De valgfrie `MM4_CD_MOUNT` og `MM4_CD_DEVICE` ændrer kun den forventede fysiske mapping, aldrig Wine-links eller CD. Standardværdierne ovenfor er de lokalt afprøvede; andre drev kræver ny kontrol. Ingen installering, ISO-udpakning, registerrettelse eller runner-download udføres af launcheren.
