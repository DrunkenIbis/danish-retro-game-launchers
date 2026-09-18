# Overboard: godkendt intro- og vinduesløsning

## Resultat og accept

Brugeren godkendte den sidste selvstændige test: introfilmen fylder spilvinduet korrekt, og spillet opleves mere flydende. Godkendelsen gælder normal **window mode**, ikke eksklusiv eller kantløs fuldskærm. Denne opsætning er nu indarbejdet i AppImage-kilderne. Den endelige genbyggede AppImage testes særskilt; en godkendt prototype er ikke i sig selv en godkendelse af alle pakkedetaljer.

Den tidligere fungerende pakke er bevaret. Den genbyggede slutfil er også startet og visuelt kontrolleret: screenshot `local/appimage-verify/overboard/windowed16-package.png` viser den animerede intro korrekt skaleret i et almindeligt 1024×768-vindue. Vinduestilstand blev aflæst uden fullscreen-flag og med dekorationer. `/proc` bekræftede både `Ob.exe` via Wine og Xephyr fra AppImage-mountet, ikke de udviklingsinstallerede programmer. Det udpakkede `game/display_runner.py` matchede opskriftens kildefil. Regressionstests bestod. SHA256 for denne slutfil: `fbb228868bb2eb5f22d173d894bab97d8fe8263c03764e72e3281314cf8095de`. Brugergodkendelsen af styring og lyd gælder den forudgående tilsvarende testopsætning; der er ikke udført en ny lang gameplay-test i slutpakken.

- Ny: `local/appimage-dist/Overboard-x86_64.AppImage`
- Reserve: `local/appimage-dist/Overboard-classic-backup-x86_64.AppImage`
- Reservefunktion i ny pakke: `OVERBOARD_DISPLAY_MODE=classic`

## Den fungerende kombination

1. Original installation i et separat Wine-GE 7-43 win32-prefix, Windows 98-kompatibilitet. Ingen ændring af spillets EXE eller videofiler.
2. Brugerens komplette mixed-mode BIN/TOC i CDEmu/VHBA. Et almindeligt data-ISO er ikke ækvivalent: cd'en har ét dataspor og 30 lydspor.
3. Gamescope som ydre vindue: `--backend sdl -W 1024 -H 768 -w 1024 -h 768 -S fit -F linear`, med `SDL_VIDEODRIVER=x11`.
4. Ingen `-f` eller `-b`: vinduet har ramme/titelbjælke og er ikke fullscreen.
5. Xephyr som indre X-skærm: `-screen 1024x768x16 -resizeable -nolisten tcp -noreset`. AppImage vælger et ledigt display via `-displayfd`; ingen fast :4 i den pakkede løsning.
6. Wine starter gennem `explorer /desktop=OverboardFixed,1024x768`. Direkte EXE-start uden Explorer var sort i denne kombination.
7. En størrelseshjælper følger kun vinduet med titlen `OverboardFixed - Wine desktop` inde på den isolerede X-skærm. Den ændrer Xephyrs RandR-mode til spilvinduets faktiske mål. Det ydre Gamescope-vindue forbliver uændret og skalerer med bevaret billedformat.
8. Hjælperen melder **READY før spilstart**. Den tidligere manuelle start flere værktøjskald efter spillet gav en synlig forsinkelse, før introen blev skaleret. Der anvendes stadig 0,1-sekunds polling; det er ikke en implementeret eventdrevet løsning.
9. `WINEDEBUG=-all` i normal drift. Den tunge `+ddraw`-log bruges kun ved fejlsøgning.
10. Når X-skærmen lukkes, håndteres `ConnectionClosedError` som normal afslutning. Den oprindelige hjælper gav ellers en misvisende exitkode 1 efter brugerens normale lukning.

## Hvad vi faktisk fandt

### Sort intro var ikke bevis for et manglende codec

Der var tydelig lyd, men sort billede. SHA256 for alle fem installerede MPX-filer matchede cd-kopien. Filerne identificerer sig som Psygnosis MPEG-1-animation; spillets EXE har egne decoder-strenge og DirectDraw-imports. Generisk ffmpeg viste slice-fejl, men det var ikke grundlag for at konvertere dette format.

Den normale Wine-kørsel låste en 320×240-billedflade med **32-bit RGB** under film. Et isoleret **16-bit RGB565**-miljø viste både logo og animeret intro med uændrede filer. Det er stærk evidens for en farvedybdeafhængig afkodnings-/visningsfejl; vi har ikke bevist den præcise fejl i spillets maskinkode.

### Et fast ydre vindue er ikke nok

Spillet skifter intern opløsning under opstart. Filmen er 320×192 inde i et 320×240-område. Først var Xephyr stadig 640×480, så filmen lå lille i øverste venstre hjørne. Da hjælperen tilpassede Xephyr til 320×240, kunne Gamescope skalere hele billedet op. Ved menu/spil følger hjælperen tilbage til eksempelvis 640×480, 800×600 eller 1024×768.

Bevar proportionerne: sorte bjælker er korrekte, når filmens format ikke matcher vinduet. Stræk ikke filmen for at skjule bjælkerne.

### Start med tilstrækkelig maksimal opløsning

640×480 som indre startskrivebord gav brugeren for få brugbare opløsningsvalg. Vi ændrede både Xephyr og Wine Explorer til 1024×768. Senere log viste skift til 800×600 og 1024×768. Et større ydre vindue alene giver kun opskalering, ikke højere intern detaljegrad.

### Fuldskærm var et forkert valg her

Testen med `-f -b` og 3840×1080 gav hakken, var ikke den window mode brugeren ønskede, og Gamescope-processen sluttede med kode 139. Den blev forkastet. Wine inde i Xephyr rapporterede `llvmpipe`, altså software-rendering; Gamescope brugte Intel HD 530 til den ydre komposition. Høj intern opløsning og stor fuldskærmskomposition kan derfor koste mere, end det ser ud til. Den præcise fordeling af ydelsesgevinsten mellem mindre vindue, deaktivere debug og tidligere hjælperstart er ikke målt.

## Forkastede forsøg

- Wine GDI: stadig sort intro.
- Wine 11 i en separat kopi: prefix-opgradering gik i stå; ingen brugbar sammenligning af video.
- dxwrapper Dd7to9: dialog om utilstrækkelig 3D-acceleration.
- dxwrapper native DirectDraw med tvungen 16-bit: Wine `d3d_viewport_vtbl`-assertion.
- Ingen af disse wrapper-DLL'er indgår i pakken.

## Pakkens opbygning og begrænsninger

`extras/build_appimage.sh` bruger repoets fælles Wine-builder. Den medtager Wine-GE, Xephyr, Python-Xlib/six, installeret prefix og brugerens BIN/TOC. Python-afhængigheder er med i pakken: ingen uv-download ved spilstart.

Værten skal stadig have Python 3, Gamescope, CDEmu/VHBA, udisksctl/findmnt og kompatible systembiblioteker. VHBA er et kernemodul og kan ikke gøres uafhængigt af værtskernen inde i AppImage. Dette er en privat lokal pakke med spilfiler, ikke en pakke til offentlig distribution.

Runtime kopierer skrivbare filer til `~/.local/share/overboard-appimage`, reserverer et tomt virtuelt cd-drev uden at forstyrre andre spil, omskriver TOC-stier og rydder op ved afslutning. Efter registeropsætning stoppes den korte Wine-session og ventes færdig, før spillet starter på Xephyrs display. `wineserver -k` kan returnere 1, hvis serveren allerede er lukket; det er ikke alene en opstartsfejl.

## Genbrug til andre projekter

- Adskil cd-validering, videodekodning, billedformat/farvedybde, vinduesstyring og 3D-ydelse i separate hypoteser.
- Test originale filer i forskellige farvedybder før codec-installationer eller transcoding.
- Skeln mellem spillets interne opløsning og det ydre vindues opløsning.
- Gør displayhjælpere klar før start, og verificér deres faktiske effekt med screenshots og geometri.
- Behandl brugerens normale lukning som normal cleanup, ikke et falsk crash fra hjælperen.
- Verificér faktisk renderer; et GPU-komponeret ydre vindue betyder ikke, at spillets 3D bruger GPU'en.
- Hold fungerende prefix/AppImage intakt, mens alternativer afprøves.
- Generalisér ikke 16-bit-løsningen til alle Wine-spil: dette er en verificeret løsning for denne titel og opsætning.
