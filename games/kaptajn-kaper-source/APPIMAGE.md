# AppImage — Kaptajn Kaper Version 1 Release 3 (1.3)

## Aktuel levering

`extras/dist/kaptajn-kaper-v1-release3-source-x86_64.AppImage`

- Størrelse: 21.750.976 bytes.
- SHA256: `6c45f7b03bf473cadd0d96cad7e66cc9fa4fae44c53c49933e21bde2ac9d0a0a`.
- Opskriftcommit: `cb2cbce4e904fc8e27b28a08b86d62f3328633bc`.
- Byg: `./games/kaptajn-kaper-source/extras/build_appimage.sh`.
- Bundlet Python 3.12, PC-BASIC 2.0.7 og SDL2; PyInstaller 6.16.0.
- Fastlåst upstream: `32ee1365f2026748ec2e7079e7395f143026e751`.
- Ingen DOSBox, Wine eller KAPER.EXE; BASIC-kilden fortolkes direkte.

## Verifikation

- Tre input-regressionstests består; shellsyntaks godkendt.
- Rent seed-genererende build og den færdige AppImages `--version`: exit 0.
- Færdig pakke udtrukket: begge desktopfiler/version 1.3 og alle tre ikoner kontrolleret.
- Alle 13 runtime-filhashes og 9 originale upstream-filhashes matcher manifestet.
- Alle opskriftfilhashes matcher byggeproveniensen.
- Pakkens SPECIAL.BAS er byte-identisk med programmet i brugerens afsluttende test.
- Brugeren bekræftede forbedret bevægelse, F1-hjælp to gange med retur til kortet og hørbar lyd i kamp i inputrettelsens tidligere build.
- Ingen ny interaktiv test efter denne slutgenbygning, efter brugerens udtrykkelige ønske.
- Release 5 bevaret uændret: SHA256 `cb4452618ffdfde147eab46a44af067af0b85507019a210409b860e6b96851b9`.

## Afgrænsning

Esc, fuld gennemspilning og andre Linux-distributioner er ikke verificeret.
Brugerbekræftet lyd i kamp er ikke en udtømmende test af gentagen F2-skiftning.
Eksisterende brugerdata migreres kun ved kendt original SPECIAL.BAS-hash,
med backup; denne migrationsvej er ikke særskilt integrationstestet.
Ingen ændring af Release 5 eller brugerens gemmedata under slutbygningen.

## Tilstand og proveniens

Brugerdata: `${XDG_DATA_HOME:-$HOME/.local/share}/kaptajn-kaper-source`.
Første start seeder atomisk. Gemmedata bevares; kun kendt original SPECIAL.BAS
opgraderes til inputrettelsen. Tilpasset BASIC-kode overskrives ikke.
Originale kilder/licens ligger i `upstream-source/`; `source-recipe.py`
beskriver tilpasningerne, og `build-provenance.json` indeholder hashes.

Lokal verifikationsrapport: `local/runtime/kaptajn-kaper-source/final-verification.json`.
Den tidligere pakke bevares som `.previous-364c304f48c9` ved siden af den nye.
AppImages, spildata og runtime holdes uden for Git; kun opskrift og dokumentation committes.
