# 💣 Atomic Bomberman (1997) Fejlfinding & Løsning (Model for Andre LLM'er)
## Oprindelig blocker-analyse og root cause
Dette dokument beskriver, hvorfor de første forsøg på at køre spillet fejlede. At forstå disse fejl er kritisk, når man udvikler AI-agenter til retro-gaming launchers.

**🛑 FEJLEN:** De tidlige scripts (før v1.2) mislykkedes gentagne gange og stoppede med en exit code 1 eller 127.
**🚨 DEN HOVEDBLOKEREN:** Fejlen lå ikke i Wine/systemet, men i **launcher-arkitekturen**. Scriptsene antog et for komplekst installationsforløb (Installer -> Setup -> Launch) frem for at adressere det faktiske medieformat og spillets *ægte* launchpunkt.

### 📜 Trinvis fejlfindingsoversigt
1.  **Media Inspection:** Det første kritiske skridt er altid at køre `7z l -slt <ISO>` og inspicere `AUTORUN.INF` i kombination med `file` og `strings` på de primære eksekverbare filer (`*SETUP*.EXE`, `*LAUNCHER*.EXE`).
2.  **Den sande EXE:** Ved Atomic Bomberman viser inspektion, at **`BM95.EXE`** er den faktiske spilstarter i ISO-roden (ikke en sekundær setup-launcher). Dette skaber et krav om direkte appel til denne fil.
3.  **Flow Correction:** Man skal springe over det "Installer"-flow og gå direkte til et **"Game Mode"**, som insisterer på:
    a. Brug af `wine32` arkitektur.
    b. Initialisering af en dedikeret Wine prefix i den korrekte sti (`local/runtime/<game-id>/wineprefix32`).
    c. Mapping af CDROM til et virtuelt drev (`D:`).
    d. Eksplicit kald til `D:\BM95.EXE` under det virtuelle skrivebord, hvilket sikrer korrekt kontekst og stier for ældre spil.

## ✅ Den succesfulde arbejdsgang (The Correct Recipe)
*   **Mål:** At starte den visuelle session ved at kalde `D:\BM95.EXE`.
*   **Værktøj:** `wine32` er obligatorisk for ældre Windows 95/98-titler.
*   **Kontekst:** Den korrekte sti til spillets data skal være en *hard-linked mount* fra det udpakkede ISO indhold (`local/runtime/.../cdrom`).
*   **Verifikation (The Ultimate Test):** Succes defineres ikke af, at scriptet kører uden fejl, men ved at **visuelt bekræfte**, at spillet når et kendt *spil-specifikt* skærmbillede (f.eks. Memory Model valgdialogen i dette tilfælde).

## 💡 Konklusion for fremtidige modeller
Altid: Behandl ISO'er fra ældre retrospil som et **"Game Root Directory"** med en `AUTORUN.INF` og *ikke* kun som en "Installer". Det mest kritiske er at finde det direkte spil-EXE, der kører på CD-rodeniveau.

## 📦 AppImage-pakning: hvad gik galt, og hvad virkede

Det første AppImage-forsøg fejlede ikke på grund af Wine eller selve spillet. Det fejlede, fordi `extras/build_appimage.sh` var en halvkopi af et fungerende per-game script.

### Den konkrete fejl

Scriptet stoppede med:

```text
./build_appimage.sh: line 95: wine_appimage_validate_base_tools: command not found
```

Root cause:

1. Scriptet kaldte AppImage-helper-funktioner som:
   - `wine_appimage_validate_base_tools`
   - `wine_appimage_reset_dirs`
   - `wine_appimage_copy_wine_runtime`
2. Men det sourcede den forkerte shared helper.
3. Den rigtige shared helper i repoet er:
   - `scripts/wine-appimage-builder.sh`
4. Den gamle Atomic-version sourcede i stedet en anden helper og beholdt samtidig Pink Panther-rester (`HPP`-navne og forkert ikon-path).

### Den rigtige løsning

Løsningen var at omskrive `extras/build_appimage.sh` til at følge samme mønster som de fungerende spil:

1. source `scripts/wine-appimage-builder.sh`
2. kald `wine_appimage_init_defaults`
3. behold den fælles AppImage-pipeline intakt
4. udskift kun de per-game specifikke værdier for Atomic Bomberman:
   - `PROJECT_NAME="atomic-bomberman-1997"`
   - `DISPLAY_NAME="Atomic Bomberman (1997)"`
   - `AB_*` runtime/source variabler
   - `BM95.EXE`
   - `BM95.ICO`

### Verificeret resultat

Den færdige build producerede:

```text
games/atomic-bomberman-1997/extras/dist/atomic-bomberman-1997-x86_64.AppImage
```

Den byggede AppImage blev derefter smoke-testet og viste både:

1. rigtige processer:

```text
./atomic-bomberman-1997-x86_64.AppImage
C:\windows\system32\explorer.exe /desktop=AtomicBomberman,800x600 D:\BM95.EXE
D:\BM95.EXE
```

2. rigtig spilskærm:

```text
Start Game
Start Network Game
Join Network Game
Options
About Bomberman
Online Manual
Exit Bomberman
```

Det beviser, at AppImage'en ikke bare bygger teknisk korrekt, men faktisk starter det rigtige spil helt ind til hovedmenuen.
