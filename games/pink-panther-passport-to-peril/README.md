# Den Lyserøde Panter på hemmelig mission i udlandet

Også kendt som: The Pink Panther: Passport to Peril (DK)

Status: installer + launcher er migreret til repoets recipe pipeline og verificeret mod den kendte danske `PANTER` ISO.
Runner: Wine / wine32, win32-prefix, Win98-kompatibilitet.

Denne mappe indeholder kun opskriften. Den indeholder ikke spillets ISO, udpakkede CD-data, Wine-prefix eller installerede spilfiler.

## Kilde

Reference-downloaden brugt af opskriften er:

```text
https://archive.org/download/DenLyserodePanterpahemmeligmissioniudlandet/PANTER.iso
```

Metadata fra kilden:

- Titel: Den Lyserøde Panter på hemmelig mission i udlandet
- Engelsk titel: The Pink Panther: Passport to Peril
- Udgiver/udvikler: Wanderlust Interactive
- År: 1996
- Sprog: dansk
- ISO volume label: `PANTER`

Brug kun opskriften med en lovligt erhvervet kopi.

## Installér eller importér ISO

Fra repo-roden:

```sh
./games/pink-panther-passport-to-peril/install.sh --download --no-launch
```

Eller validér en eksisterende lokal ISO:

```sh
PP_ISO=/sti/til/PANTER.iso ./games/pink-panther-passport-to-peril/install.sh --existing --no-launch
```

Som standard lægges private filer her:

```text
local/sources/pink-panther-passport-to-peril/PANTER.iso
local/runtime/pink-panther-passport-to-peril/
```

De mapper er ignoreret af Git.

## Start spillet

```sh
./games/pink-panther-passport-to-peril/launch.sh
```

Hvis ISO'en ligger et andet sted:

```sh
PP_ISO=/sti/til/PANTER.iso ./games/pink-panther-passport-to-peril/launch.sh
```

For kun at forberede runtime uden at åbne spilvinduet:

```sh
PP_MODE=prepare ./games/pink-panther-passport-to-peril/launch.sh
```

Stop Wine-prefixen efter test:

```sh
PP_MODE=kill ./games/pink-panther-passport-to-peril/launch.sh
```

## Launch modes

- `PP_MODE=game` / `installed` (standard): lav en clean install under Wine-prefixen og start `C:\Program Files\Pink Panther\PPTP.EXE`.
- `PP_MODE=cdgame` / `cdexe`: start `D:\INSTALL\PPTP.EXE` direkte fra den udpakkede CD. Dette er primært en debug/fallback mode.
- `PP_MODE=teaser`: start `D:\TEASER.EXE`, som `AUTORUN.INF` peger på.
- `PP_MODE=setup`: start `D:\SETUP.EXE`. Den er en gammel Win16/NE Windows 3.1 installer og kræver en Wine-installation der kan køre Win16/wine32.
- `PP_MODE=prepare`: udpak ISO, initier prefix, map CD og lav clean install, men start ikke spillet.
- `PP_MODE=kill`: stop wineserver for denne prefix.

## Hvorfor disse særlige Wine-indstillinger bruges

De samme forklaringer står som kommentarer i `launch.sh`, fordi launcheren er den kanoniske kilde til kompatibilitetsvalgene.

1. Recipe-only paths
   - ISO'en læses fra `local/sources/pink-panther-passport-to-peril/PANTER.iso` eller `PP_ISO`.
   - Udpakning, Wine-prefix og clean install skrives til `local/runtime/pink-panther-passport-to-peril/` eller `PP_RUNTIME_DIR`.
   - Det holder ISO, CD-udtræk og Wine-prefix ude af Git.

2. `wine32` og win32-prefix
   - `SETUP.EXE` er en gammel Win16/NE Windows 3.1 installer.
   - Det egentlige spil `INSTALL/PPTP.EXE` er PE32.
   - Et win32 Wine-prefix er den mest stabile konfiguration for denne Win95/Win98-era titel.

3. Manuel clean install uden gamle system-DLL'er
   - CD'ens `INSTALL/` mappe indeholder gamle Windows/Win32s systemfiler som `VERSION.DLL`, `COMDLG32.DLL`, `SHELL32.DLL`, `WINSPOOL.DRV`, WinG og Win32s DLL'er.
   - Hvis de ligger ved siden af `PPTP.EXE`, kan de skygge for Wine's egne DLL'er og give loader-fejl som `c000007b`.
   - Launcheren kopierer derfor spil- og datafiler til `C:\Program Files\Pink Panther`, men udelader de gamle systemfiler.

4. CD-ROM mapping
   - Den udpakkede ISO mappes som `D:` og får label `PANTER`.
   - Det bevarer den oprindelige CD-kontekst til ressourceopslag.

5. Win98-kompatibilitet og 640x480 Wine desktop
   - Prefixens Windows-version sættes til `win98`.
   - Spillet startes som standard i Wine Explorer virtual desktop `PinkPanther,640x480`.
   - Det reducerer problemer med gamle 2D/DirectDraw-vinduer under moderne window managers.

## Første start

Ved første start kan spillet vise en dansk dialog med Pink Panther-figuren:

```text
Ændrer skærmopsætning
Den bedste skærmopsætning er 640x480, 256 farver. Ønsker du opsætningen ændret?
```

Klik `Ja`. I testen fortsatte spillet derefter fra prompten til faktisk Pink Panther-spilindhold/intro, ikke kun et tomt Wine-vindue.

## Verificeret ISO-indhold

Den danske ISO har bl.a. disse nødvendige filer:

```text
AUTORUN.INF       -> open=teaser.exe
TEASER.EXE        -> PE32 autorun/teaser
SETUP.EXE         -> Win16/NE Windows 3.1 installer
INSTALL/PPTP.EXE  -> PE32 hovedspil
INSTALL/PPTP.BRO
INSTALL/PPTP.HLP
ALLSONGS.PTP
PPTP.ORB
```

## Lutris

`lutris.yml` bruger Linux-runneren og kalder `./launch.sh`, så alle kompatibilitetsvalg ligger ét sted. Importér den som lokal install script i Lutris, eller kør wrapperen direkte.
