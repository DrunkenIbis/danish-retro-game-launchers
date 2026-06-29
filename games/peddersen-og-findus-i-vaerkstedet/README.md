# Peddersen og Findus i værkstedet

Status: working gameplay verified via repo-local Wine launcher.
Runner: Wine / wine32, win32-prefix, Win98-kompatibilitet.

Denne mappe indeholder kun opskriften. Den indeholder ikke spillets ISO, udpakkede CD-data, Wine-prefix, screenshots eller installerede spilfiler.

## Kilde

Reference-downloaden brugt af opskriften er:

```text
https://archive.org/download/peddersen-og-findus-i-vaerkstedet_202201/Peddersen%20og%20Findus%20i%20v%C3%A6rkstedet.iso
```

Metadata:

- Titel: Peddersen og Findus i værkstedet
- Udgiver: Gammafon
- År: ukendt; ISO-filerne er observeret med 2003-timestamps og `Læs mig.txt` siger version 2.0
- Sprog: dansk / nordisk
- Platform: Windows PC CD-ROM
- ISO volume label: `FINDUS1`
- SHA256 for den testede ISO: `9d1d255889adf1ccd94252b04b31dba566258c4c682f605aea6fe12571d9d1c4`

Brug kun opskriften med en lovligt erhvervet kopi.

## Installér eller importér ISO

Fra repo-roden:

```sh
./games/peddersen-og-findus-i-vaerkstedet/install.sh --download --no-launch
```

Eller validér en eksisterende lokal ISO:

```sh
FINDUS1_ISO=/sti/til/Peddersen-og-Findus-i-vaerkstedet.iso ./games/peddersen-og-findus-i-vaerkstedet/install.sh --existing --no-launch
```

Som standard lægges private filer her:

```text
local/sources/peddersen-og-findus-i-vaerkstedet/Peddersen-og-Findus-i-vaerkstedet.iso
local/runtime/peddersen-og-findus-i-vaerkstedet/
```

De mapper er ignoreret af Git.

## Start spillet

```sh
./games/peddersen-og-findus-i-vaerkstedet/launch.sh
```

Hvis ISO'en ligger et andet sted:

```sh
FINDUS1_ISO=/sti/til/Peddersen-og-Findus-i-vaerkstedet.iso ./games/peddersen-og-findus-i-vaerkstedet/launch.sh
```

For kun at forberede runtime uden at åbne spilvinduet:

```sh
FINDUS1_MODE=prepare ./games/peddersen-og-findus-i-vaerkstedet/launch.sh
```

Stop Wine-prefixen efter test:

```sh
FINDUS1_MODE=kill ./games/peddersen-og-findus-i-vaerkstedet/launch.sh
```

## Launch modes

- `FINDUS1_MODE=game` / `installed` (standard): lav en manuel runtime-install og start `C:\Program Files\Findus1\Findus1.exe`.
- `FINDUS1_MODE=prepare`: udpak ISO, initier prefix, map CD, kopier runtime-install og skriv registry-nøgle, men start ikke spillet.
- `FINDUS1_MODE=cdgame` / `cdexe`: start `D:\DATA\Findus1.exe` direkte fra den udpakkede CD. Testet som debug-mode; uden installeret registry/runtime-state viser spillet dialogen `Findus1 skal installeres først.`
- `FINDUS1_MODE=autorun`: start CD'ens `D:\autorun\Autorun.exe`.
- `FINDUS1_MODE=setup`: start CD'ens `D:\Installér Findus1.exe`.
- `FINDUS1_MODE=settings`: start det installerede `Indstillinger.exe`.
- `FINDUS1_MODE=kill`: stop wineserver for denne prefix.

## Hvorfor launcheren laver en manuel install

ISO'en er inspiceret før launch path blev valgt:

```text
autorun.inf              -> open=autorun\autorun.exe
autorun/autorun.ini      -> install_path=..\Installér Findus1.exe
DATA/Findus1.exe         -> PE32 Macromedia Director 8.5 hovedspil
DATA/Indstillinger.exe   -> PE32 indstillingsprogram
Installér Findus1.exe    -> PE32 installer
Media/*.dxr + Cast/*.cxt -> Director-ressourcer
```

Direkte start af `D:\DATA\Findus1.exe` blev testet og gav en Wine-dialog med teksten `Findus1 skal installeres først.` Det er ikke nok at mappe CD'en; spillet kræver installeret state.

Den verificerede wrapper gør derfor dette:

1. Udpakker ISO'en til `local/runtime/peddersen-og-findus-i-vaerkstedet/cdrom`.
2. Initialiserer et win32 Wine-prefix og sætter Windows-version til `win98`.
3. Mapper den udpakkede CD som Wine `D:` med label `FINDUS1`.
4. Kopierer `DATA/` og `Media/` til `C:\Program Files\Findus1`.
5. Laver et lowercase `media -> Media` symlink i runtime-installationen, fordi Director 8 laver nogle lowercase resource-opslag på et case-sensitive host-filsystem.
6. Skriver `HKLM\Software\Gammafon\Findus1` default-værdien til `C:\Program Files\Findus1\Findus1.exe`.
7. Starter `Findus1.exe` i en `Findus1,800x600` Wine virtual desktop.

## Verificeret gameplay

Repo-local test på denne maskine:

- `install.sh --existing --no-launch` validerede den downloadede ISO mod de forventede filer.
- `FINDUS1_MODE=prepare ./launch.sh` udpakkkede ISO'en, oprettede Wine-prefixen, kopierede den manuelle install og skrev registry-nøglen.
- Første direkte CD-test viste kun `Findus1 skal installeres først`, så direct-CD mode blev ikke markeret som working.
- Standard `game` mode viste først titelskærmen `Peddersen og Findus i værkstedet`.
- Efter input forlod spillet titelskærmen og viste den interaktive gård/værksted-scene med huse, dyr og UI-knapper. Det blev verificeret med screenshot af Wine-vinduet, ikke kun proces/timeout/splash.

## Lutris

`lutris.yml` bruger Linux-runneren og kalder `./launch.sh`, så alle kompatibilitetsvalg ligger ét sted. Importér den som lokal install script i Lutris, eller kør wrapperen direkte.

## AppImage

`extras/build_appimage.sh` bruger repoets fælles `scripts/wine-appimage-builder.sh` helper og pakker den verificerede Wine-runtime, den udpakkede CD og en seedet Wine-prefix i en AppDir/AppImage.

Typisk flow fra repo-roden:

```sh
./games/peddersen-og-findus-i-vaerkstedet/install.sh --download --no-launch
FINDUS1_MODE=prepare ./games/peddersen-og-findus-i-vaerkstedet/launch.sh
./games/peddersen-og-findus-i-vaerkstedet/extras/build_appimage.sh
```

Kun AppDir-verifikation uden endelig AppImage:

```sh
./games/peddersen-og-findus-i-vaerkstedet/extras/build_appimage.sh --appdir-only
```

Testet output på denne maskine:

```text
games/peddersen-og-findus-i-vaerkstedet/extras/dist/peddersen-og-findus-i-vaerkstedet-x86_64.AppImage
størrelse: 558712000 bytes / ca. 533 MiB
```

AppImage-smoke-testen blev kørt med frisk `XDG_DATA_HOME` under `local/runtime/.../appimage-test-data`. Processlisten viste AppImage-mountet `/tmp/.mount_pedder...`, bundled Wine/wineserver fra mountet og `C:\Program Files\Findus1\Findus1.exe`. Vinduet nåede titelskærmen og kunne derefter avanceres til den interaktive gård/værksted-scene. Den eneste observerede støj var en forventet/tolereret read-only advarsel, når launcheren forsøgte at skrive `.windows-label` på CD-ROM-mappen inde i AppImage-mountet.

AppImage-filen og `extras/build/`, `extras/dist/`, `.cache-appimage/` er runtime/build-output og ignoreres af Git.
