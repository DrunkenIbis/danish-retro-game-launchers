# AppImage — Kaptajn Kaper Version 1 Release 3 (1.3)

## Levering

`extras/dist/kaptajn-kaper-v1-release3-source-x86_64.AppImage`

- Størrelse: 21.738.688 bytes.
- SHA256: `af83e0153ddae77eec51bddfe68276922d191a3779a5813d717dec9e561f1d2c`.
- Byg: `./games/kaptajn-kaper-source/extras/build_appimage.sh`.
- Runtime: indbygget Python 3.12, PC-BASIC 2.0.7 og SDL2; PyInstaller 6.16.0 onedir.
- Spil: SPECIAL.BAS fra kb-dk commit `32ee1365f2026748ec2e7079e7395f143026e751`.
- Ingen DOSBox, Wine eller KAPER.EXE. BASIC fortolkes direkte; dette er ikke en ny kompileret udgave af spillet.

## Kontrolleret

- Byg og `--version` afsluttede med exit 0 fra den færdige AppImage.
- Færdig pakke udtrukket: versionsangivelse 1.3, begge desktop-filer og alle tre ikonplaceringer kontrolleret.
- Alle 13 runtime-filer og 9 originale upstream-filer matchede manifestets SHA256.
- Den færdige AppImage startet med frisk, isoleret XDG_DATA_HOME; Kattegat-kort visuelt verificeret.
- `/proc/1101353/exe` pegede på AppImage-mountens `/runtime/pcbasic`, ikke system-Python eller udviklingsmiljøet.
- Skriveadgang lå i den separate testmappe, ikke AppImage-mounten.
- Release 5-AppImage bevaret med uændret SHA256 `cb4452618ffdfde147eab46a44af067af0b85507019a210409b860e6b96851b9`.

## Ikke bekræftet

Fuldt gameplay, hørbar lyd, genstart med eksisterende spiltilstand og kørsel på en anden Linux-distribution er ikke særskilt bekræftet.
Kortvisning er opstarts-/grafikevidens, ikke fuld gameplay-verifikation. Ingen krav om gentaget gameplay-test af Release 5.

## Tilstand og proveniens

Normal brugerdata: `${XDG_DATA_HOME:-$HOME/.local/share}/kaptajn-kaper-source`.
Første start kopierer en frisk seed atomisk; eksisterende spilmappe overskrives ikke.
Testdata: `local/runtime/kaptajn-kaper-source/appimage-test-data/`.
Pakkeverifikation: `local/runtime/kaptajn-kaper-source/package-check/verification.json`.
Originale BASIC-kilder og GPL-licens er i `upstream-source/` inde i pakken;
`source-recipe.py` beskriver SKUD.BAS-tilpasningen. `build-provenance.json` indeholder checksums og kildecommit.

Byggefiler, fortolker, spildata og AppImage holdes uden for Git. Kun byggeopskriften og dokumentation pushes.
