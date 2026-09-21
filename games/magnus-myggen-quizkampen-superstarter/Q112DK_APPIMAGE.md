# Quizkampen Q112DK – privat AppImage uden fysisk CD

Denne **separate** build bruger den originale Q112DK-installation, hvis gameplay
brugeren har bekræftet med ISO i CDEmu og den fysiske CD skubbet ud. Den gamle
`extras/build_appimage.sh` er Q122DK/SuperStarter/CAB-sporet og er **ikke** en
fungerende erstatning; brug ikke det gamle artifact til denne test.

```bash
bash games/magnus-myggen-quizkampen-superstarter/extras/build_q112dk_appimage.sh
./local/appimage-dist/Quizkampen-Q112DK-WineGE-x86_64.AppImage --check
./local/appimage-dist/Quizkampen-Q112DK-WineGE-x86_64.AppImage
```

## Indhold og forudsætninger

- Hele `lutris-GE-Proton7-43-x86_64` med parret Wine/wineserver.
- Kopi af det stoppede `image-q112dk-ge/wineprefix32`, inklusive den originale
  installation. `physical-q112dk-ge/wineprefix32` ændres ikke.
- Original single-data-track ISO: 30296064 bytes,
  SHA-256 `b9e9b4f6edf703ad5be18638852c81e41a8dd964aca9191586ecdd8c549af1bd`.
- **Værten skal allerede have CDEmu-daemon, aktivt VHBA-kernelmodul, Python 3,
  cdemu, udisksctl, findmnt, cp og kompatible 32-/64-bit Wine-systembiblioteker.**
  Der installeres ingen pakker, moduler eller systemkonfiguration. AppImage-FUSE
  skal fungere; ellers brug `--appimage-extract` og `squashfs-root/AppRun`.
- Dette er CD-frit, men ikke fuldstændigt selvstændigt: CDEmu/VHBA og
  grafik-/lyd-/systembiblioteker er værtsafhængigheder. Kun lokal privat brug;
  game-data, prefix, registrering, ISO, logs og builds må ikke publiceres i Git.

## Runtime

Prefix og en hash-verificeret ISO-kopi lægges i
`${XDG_DATA_HOME:-$HOME/.local/share}/quizkampen-q112dk-appimage`.
`MMQ_Q112DK_STATE=/absolut/sti` vælger en separat testtilstand. Spillets output
ligger i `game.log` der. Bundlen bruger ingen repository-stier ved start.

Launcheren vælger et tomt CDEmu-drev; hvis alle er optaget, beder den daemonen
om et ekstra virtuelt drev. Allerede indlæste medier aflæsses aldrig for at gøre
plads. Mangel på et ledigt/nyt drev giver en fejl, ikke fysisk-CD-fallback.
Efter load afventes mapping, blok-enhed og læserettighed på det valgte drev i
højst 15 sekunder (poll hver 0,5 s; mapping-kommandoen har samme deadline), så
udev kan oprette enheden og dens ACL. Timeout giver fejl og normal cleanup,
ikke fallback til et andet drev. Kun den valgte CDEmu-enhed monteres.
Mount-readback kræver samme blok-enhed og
label `Q112DK`; gamle Wine-drevmappings fjernes før start og host-drev, som Wine
opdager under opstart, fjernes igen. Det validerede virtuelle drev bliver D:/D::.

Spillet startes med bundlet Wine, `WINEARCH=win32`,
`WINEDLLOVERRIDES=mscoree,mshtml=`, `WINEDEBUG=-all`,
`explorer /desktop=Quizkampen,800x600` og originalt `mm12main.EXE` fra den
installerede mappe. Normal exit venter på bundlet `wineserver -w`, da Explorer
kan returnere før spillet. Ved fejl/afbrydelse stoppes kun dette prefix og
serveren afventes før mediet ryddes op. Hvis serveren ikke stopper inden 20 s,
beholdes mediet indlæst frem for at afbryde levende Wine-processers diskadgang.
Cleanup aflæser kun drevet, hvis CDEmu stadig viser launcherens egen ISO.
Et nyt virtuelt drev efterlades tomt til genbrug. Undgå at ændre samme drev
manuelt under spillet; CDEmu-klienter har ingen fælles atomisk reservation.

## Verifikation og afgrænsning

```bash
python3 games/magnus-myggen-quizkampen-superstarter/extras/test_q112dk_appimage.py
bash -n games/magnus-myggen-quizkampen-superstarter/extras/build_q112dk_appimage.sh
```

Fixture-tests dækker writable seed/ISO, ekstra frit drev uden indgreb i optaget
medie, eksakt Wine-kommando/miljø, fejlagtig mount-kilde, korrumperet ISO,
gamle/auto-opdagede fysiske mappings, Wine-fejl, server-wait-fejl og ejerskab ved
cleanup. Fixturetests starter ikke Wine eller GUI og ændrer ikke host-CDEmu.
`--check` er ligeledes read-only og starter ikke spillet.

Den færdige AppImage er nu startet med Wine fra dens eget mount og dens egen
ISO i CDEmu device 1, mens det fysiske drev stod åbent. Brugeren bekræftede:
“det virkeder rigtig godt”. Normal afslutning gav exitkode 0; device 1 blev
aflæst, og det eksisterende device 0 var uberørt. Alle 15 fixture-tests består.
En tidligere førstegangsstart afslørede en udev-readiness-race; den er rettet
med den beskrevne ventelogik og regressionstests. Gentagne gameplay-starter
og flytbarhed til andre Linux-distributioner er ikke testet. Spillets eksisterende registrering og Windows-indstillinger
bevares, og ingen EXE-/licens-/CD-check-patches anvendes.
