# Verificeret status og afgrænsning

## Samlet startvej

`launch.sh` indeholder hele den normale startvej til den eksisterende original-CD-installation. `launch_physical.sh` videresender kun til den, så tidligere kommandoer stadig virker. Skrivebordsgenvejen og den valgfrie Lutris-konfiguration peger på `launch.sh`. Ingen Lutris-afhængighed, automatisk geninstallation, test-timer eller debuglogfil.

Den gamle ISO-/manuelle installationskode er fjernet fra hoved-launcheren og kan findes i Git-historikken. Den fungerende private runtime og brugerens spiltilstand er ikke erstattet, flyttet eller nulstillet.

## Bruger- og billedverificering

- Original-CD MM4DK, fysisk `/dev/sr0`, D: til `/run/media/test/MM4DK` og D:: til rådrevet.
- Win32/Windows XP, privat GE-Proton7-43-baseret runner i `local/runtime/mm4-thunk-fix/runner` og prefix `local/runtime/mm4-graphics/prefix`.
- Standardrenderer, UseSystemMemory=0, startdesktopsstørrelse 1024×768. Spillet vælger selv 800×600/16-bit.
- Korrekt grafik i to opstarter; figurbevægelse i første rum og læsbar Escape-menu visuelt bekræftet.
- Efter manuel spiltest: brugeren svarede “det fungerede poerfekt” på spørgsmålet om musestyring og lyd. Kørslen sluttede med exit 0.
- Den efterfølgende faste genvej blev ligeledes prøvet af brugeren: “det fungerede perfekt”, også efter normal exit 0.
- Original-EXE er uændret: SHA-256 `232613c229ba96a1eb7238809a7d82e1e6257d08c850fcaaf88674f0cd207d27`.

Privat evidens findes under `local/runtime/mm4-graphics/logs/`, bl.a. `repeat-gameplay-up-35651587.png`, `repeat-menu-35651587.png`, `manual-play-ADiLs0.log`, `shortcut-start-27262979.png` og `shortcut-book-27262979.png`. Medier, spilfiler, runtime, screenshots og logs er ikke med i Git.

## Hvorfor 1024×768 ved opstart?

Et startskrivebord på 800×600 efterfulgt af spillets 800×600/16-bit-kald gav en formatkonflikt ved aktivering: primærfladen var RGB565, men senere implicitte flader blev 32-bit. Kildeanalyse af proton-wine `e9a47cbabb94d94ce03a5e7c0774e8fbf741aa96` pegede på, at `wined3d/device.c` kan springe en modeopdatering over, når dimensionerne er uændrede, mens `swapchain.c` genanvender en gemt mode ved aktivering.

At starte ved 1024×768 og lade spillet skifte til 800×600 fjernede korruptionen. Begge målte logs beholdt RGB565 og havde ingen formatkonfliktadvarsel. Det er en afprøvet konfigurations-workaround; den interne gemte mode er ikke direkte instrumenteret, så dette er ikke en generel Wine-koderettelse.

UseSystemMemory=1 hjalp ikke. En isoleret `renderer=no3d`-test gav sort billede og beholdt konflikten. Disse ændringer indgår ikke i den normale startvej.

## Kendte begrænsninger

- Dette er en eksisterende lokal installation; et rent checkout er ikke nok. En reproducerbar automatisk installation og en AppImage er ikke leveret.
- Den private runner indeholder eksperimentelt LS01-referencearbejde og DPMI/MSCDEX-læsning. De var brugt i tidligere Win98-diagnose, men deres nødvendighed i XP-sporet er ikke afklaret. LS01-arbejdet har uafklarede reentrancy-/concurrency-/stub-livstidsrisici og må ikke omtales som en generelt gennemgået Wine-rettelse.
- Kun denne lokale runner/prefix/original-CD-kombination er brugerbekræftet. En original urettet runner med samme XP-/grafikopsætning er endnu ikke testet.
- Gem/hent og fuld gennemspilning er ikke særskilt bekræftet. Lutris-importen er valgfri og ikke GUI-testet.
- Windows 98- og den konkret downloadede ISO/CDEmu-kombination var blokeret ved CD-dialogen. ISO'en afveg fra original-CD'en; resultatet afviser ikke alle mulige diskimages. Ingen EXE-patch eller falsk CD-succes bruges i den afprøvede opsætning.

## Kontroller ved samling

Elleve automatiske launcher-tests består i fixture-ejede mapper; de omfatter også alias, fejlreturer og afvisning af en eksisterende session uden at dræbe den. `bash -n`, desktop-filvalidering og reel `launch.sh --check` består. De automatiske tests er ikke gameplay-bevis; se bruger-/billedverificeringen ovenfor. Den samlede `launch.sh` blev derefter startet gennem den opdaterede skrivebordsgenvej; brugeren bekræftede igen “det fungerede perfekt”, og GIO-sporingen returnerede exitkode 0. Der blev ikke taget et nyt gameplay-screenshot af denne kørsel, fordi brugeren havde afsluttet den før capture.

Det første migrations-testforsøg ramte den gamle launchers ISO-fallback og startede system-Wine i en midlertidig fixture-mappe. Det blev stoppet prefix-afgrænset, og testens gamle MM2-indgange blev derefter gjort eksplicit fixture-ejede, så hverken brugerens ISO eller system-Wine vælges ved regression til den gamle kode. Den efterfølgende røde test fejlede rent ved den gamle ISO-forudsætning; den samlede launcher gjorde testen grøn.

## Historisk provenance

Opskriften blev oprindeligt migreret fra `/home/test/lutris_game_scripts_mm4`. Kun opskrift, konfiguration, tests og dokumentation hører til i Git. Ældre lokalt diagnosearbejde holdes adskilt fra denne fokuserede launcher-ændring.
