# Kaptajn Kaper — Version 1, Release 3 (1.3 / GitHub-kilde)

Denne parallelle udgave kører `SPECIAL.BAS` fra [kb-dk/KaptajnKaper](https://github.com/kb-dk/KaptajnKaper)
med PC-BASIC på Linux. Spillets egen versionsangivelse er **Version 1 Release 3**, kort **1.3**.
Den først installerede [ZIP/DOS-udgave](../kaptajn-kaper-2/) er **Version 1 Release 5 (1.5)**.
Det er to forskellige udgaver; GitHub-kilden er ikke kildekoden til den nyere Release 5-binærfil.

## Installation og start

```sh
./games/kaptajn-kaper-source/install.sh --no-launch
./games/kaptajn-kaper-source/launch.sh
```

Krav: Linux, Bash, Python 3, Git, uv, X11/XWayland og lydsystem.
Installationen henter isoleret Python 3.12 samt PC-BASIC 2.0.7, pysdl2-dll 2.32.10 og pyserial 3.5.
Python 3.14 kan ikke køre denne PC-BASIC-version uændret (`chunk` er fjernet).
Ingen Wine, DOSBox eller `KAPER.EXE` bruges.

Upstream fastlåses til `32ee1365f2026748ec2e7079e7395f143026e751` (GPL-3.0).
BASIC og TITEL.PIC hentes fra Git-objekterne; BUILD, SKUD, TEGN og HLP genererer de øvrige data.
SKUD.BAS linje 4000 ændres fra `goto 9000` til REM, fordi springet ellers springer skibstegning og BSAVE over.
Originalt checkout forbliver uændret; tilpasningen ligger reproducerbart i runner.py.

Separate private mapper: `local/sources/kaptajn-kaper-source/upstream` og `local/runtime/kaptajn-kaper-source`.
Overrides: `KAPER_SOURCE_GIT_DIR` og `KAPER_SOURCE_RUNTIME_DIR`.
Geninstallation bevarer REC.DAT/TEMP.PIC. Manifest indeholder kildecommit, hash og tilpasning.

## Status

Installation og alle fire datageneratorer gennemført. Startskærm og Kattegat-kort visuelt set via launch.sh.
Begge hidtidige PC-BASIC-processer afsluttede med exit 0. Sejlads/kamp og hørbar lyd er ikke fuldt verificeret.
Den tidligere brugerbekræftelse af DOS-spillet gælder Release 5, ikke automatisk denne Release 3.

**Ingen AppImage bygget af Release 3 endnu.** Release 5-AppImage må ikke forveksles med denne variant.
Hvis denne udgave pakkes senere, skal filnavnet være `kaptajn-kaper-v1-release3-source-x86_64.AppImage`,
programnavnet indeholde `Version 1 Release 3 (GitHub-kilde)`, og dens brugerdata skal holdes separat.
