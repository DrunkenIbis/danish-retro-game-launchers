# Overboard på en ny Linux-maskine

Denne private AppImage er ikke helt selvstændig. Den indeholder spil, Wine-GE,
Xephyr, Python-Xlib/six og originalens BIN/TOC-cd-kopi, men kræver værtskomponenter.
Del ikke pakken med ophavsretligt beskyttede spildata.

## Systemkrav

- x86_64 Linux, Bash og Python 3.
- CDEmu-klient (`cdemu`) og fungerende CDEmu-tjeneste/sessionens D-Bus.
- VHBA-kernemodul bygget til og indlæst i den aktive kernel.
- `udisksctl` (UDisks2), `findmnt` (util-linux) og `cp` (coreutils).
- Gamescope til standardvisningen windowed16 og en fungerende grafisk session.
- Kompatible 32-/64-bit systembiblioteker til den medfølgende Wine/Xephyr.
- AppImage-runtime skal kunne startes, normalt via FUSE.

CDEmu leverer det virtuelle mixed-mode cd-drev med data og lydspor. VHBA er en
værtsdriver: at kopiere cdemu ind i AppImagen er ikke nok. Pakken installerer
ikke systempakker, starter ikke privilegerede installationskommandoer og
ændrer ikke Secure Boot. Installation kræver separat godkendelse.

## Første kontrol

Kør fra mappen med AppImagen:

```sh
chmod +x ./Overboard-x86_64.AppImage
./Overboard-x86_64.AppImage --check
```

Kontrollen samler manglende værtskommandoer, manglende indlæst VHBA og manglende
bundlet Wine/Xephyr. Hvis cdemu findes, prøves `cdemu status` med 10 sekunders
timeout. Der indlæses ingen cd, oprettes ingen spiltilstand og startes intet spil.
Et OK er ikke en gameplay-, grafik-, lyd- eller fuld bibliotekskompatibilitetstest.
Hvis Python 3/Bash eller selve AppImage-runtime mangler, kan kontrollen ikke starte.

## Oplysninger til installation og fejlfinding

Send output fra følgende fra den maskine, hvor fejlen opstår:

```sh
cat /etc/os-release
uname -r
command -v python3 cdemu udisksctl findmnt cp gamescope
cdemu status
test -d /sys/module/vhba && printf 'VHBA indlæst\n'
```

- Manglende `cdemu`: installér distributionens CDEmu-klient, tjeneste og VHBA-pakke.
- CDEmu-tjenesten utilgængelig: undersøg `cdemu status`, tjenesten og D-Bus i den
  almindelige brugers grafiske session. Kør ikke spillet som root.
- VHBA ikke indlæst: kontrollér modul til netop den aktive kernel. Efter en
  kernelopdatering kan modulet skulle genbygges. Secure Boot kan kræve signering
  og nøgleindrullering; slå ikke Secure Boot fra som automatisk løsning.
- Gamescope mangler: installér distributionens pakke til standardvisningen.
- Biblioteksfejl efter et OK: send den præcise fejl og spillets game.log fra
  `${XDG_DATA_HOME:-$HOME/.local/share}/overboard-appimage/`.

Konkrete pakke- og installationskommandoer vælges først, når distribution,
version og kernel er kendt. Der er endnu ikke verificeret installation på Worklaptop.

Når kravene er opfyldt, kør --check igen og start derefter uden argumenter.
Kontrollér intro, gameplay, lyd og normal afslutning på den nye maskine.
`OVERBOARD_DISPLAY_MODE=classic` vælger den gamle Esc-for-at-springe-intro-over
visning uden Gamescope; den kræver stadig CDEmu/VHBA og er ikke en løsning på
manglende virtuelt cd-drev.
