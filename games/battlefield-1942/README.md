# Battlefield 1942 — WWII Anthology / SiMPLE

Anbefalet lokal variant: originalt installeret grundspil, officiel retail 1.61b og ejerens udtrykkeligt valgte SiMPLE-pakke. Ikke uændret vanilla: community-pakken ændrer CD-kontrol, widescreen, portability og masterserver-adresse. Originale 1.6- og officielle 1.61b-prefixes er bevaret separat.

## Start

Fra projektroden:

```sh
games/battlefield-1942/launch.sh
```

`launch.sh` er et relativt link til den brugerafprøvede `launch_simple.sh`. Kræver forberedt privat runtime; ingen CD, ISO-mount eller CDEmu kræves.

Privat, testet AppImage:

```text
/home/test/danish-retro-game-launchers/local/runtime/battlefield-1942/appimage-dist/Battlefield-1942-1.61b-SiMPLE-x86_64.AppImage
```

Standardbrugerdata: `~/.local/share/battlefield-1942-simple-appimage/`. `BF1942_APPIMAGE_STATE=/absolut/sti` vælger anden tilstand. Indeholder spilfiler og private registreringsdata: må ikke publiceres.

## Verifikation

| Variant | Resultat |
|---|---|
| Original 1.6 / fysisk CD | Ejer bekræftede gameplay og normal Quit. Agent så screenshot af bane/HUD. |
| Officiel 1.61b / fysisk CD | Patch og gameplay brugerbekræftet; ændrede filhashes/version kontrolleret. |
| CD 1/CD 2 backups | Begge ufuldstændige sektor-rescuekopier; alle auditerede filområder læst og 7z test OK. Ikke fulde arkivbackups. |
| Officiel 1.6/1.61b uden image | Installerede filer og mappede CD-filer giver CD-dialog. |
| Officiel 1.6/1.61b via CDEmu | Rescue-ISO giver kort sort vindue/afslutning; ikke gameplay. |
| Separat 1.61b + SiMPLE | Gameplay brugerbekræftet uden originaldisk, mount eller CDEmu-medie. |
| Færdig AppImage | Gameplay brugerbekræftet med friske og genbrugte brugerdata. Bundlet Wine/wineserver verificeret via /proc ved første kørsel; processer og mounts ryddet efter begge. |

Agenten har ikke et uafhængigt gameplay-screenshot af SiMPLE/AppImage; ejeren bad udtrykkeligt om at bruge sin visuelle kontrol. AppImage-kørsler returnerede 1; gode gameplay-resultater blev bekræftet, men normal Quit-intent er ikke særskilt registreret. Lyd, langtidsstabilitet og andre maskiner er ikke særskilt verificeret.

## Klargøring og build

1. Følg originalinstallationens undersøgte trin i INSTALLATION.md. Kun grundspil vælges. CD-kode indtastes kun i originalinstallerens vindue. Se CD 2-staging-løsningen, som genbruger Battlefield Vietnams scripts.
2. Opdatér en stoppet separat kopi med officiel patch som dokumenteret i PATCHING.md. Bevar gameplay-bekræftet 1.61b-prefix.
3. Hent den ejer-valgte SiMPLE-ZIP fra SIMPLE.md til den private cache og kør `prepare-simple.sh`. Scriptet afviser ændret ZIP-hash og eksisterende output.
4. Kør `launch.sh`, verificér gameplay og luk prefixet. AppImage-builderens standardseed er den bevarede kopi `simple161b/prefix-gameplay-verified`.
5. Kør `extras/build_appimage.sh`. Bruger projektets fælles Wine-builder, bundler hele den afprøvede Wine-runner og det klargjorte prefix, men intet CD-image.

Vigtig resterende begrænsning: ingen færdig `install.sh`/officiel-patch-wrapper er implementeret endnu. Den oprindelige installationsdel er dokumenteret fra faktisk udførelse, men en ren checkout kan endnu ikke genskabe hele forløbet via scripts alene. AppImage-builderen er reproducerbar fra det dokumenterede, klargjorte private seed; dette må ikke forveksles med en afsluttet originalmedie-til-AppImage-pipeline.

## Afhængigheder og private data

Source-launcher: den valgte Wine-runner med sibling wineserver, kompatible 32-bit grafik/systembiblioteker, bash, flock. AppImage bundler Wine, men bruger Linux/FUSE samt kompatible host-grafik/systembiblioteker; ingen generel tværdistro-selvstændighed påstås. Build kræver bl.a. Python 3, wrestool, appimagetool og fælles builder-afhængigheder. Backup kræver cd-info og GNU ddrescue; allerede lokal ddrescue kan genbruges uden systeminstallation.

Alle medier, patchbinærer, registreringsdata, prefixes, logs og builds ligger i ignorerede private paths. Dokumentation: BACKUP.md, DISC-FREE.md, PATCHING.md, SIMPLE.md og extras/README.md. Tidlige notes/installation-sektioner beskriver historiske forsøg; denne status og de konkrete slutresultater har forrang.
