# Verifikation og pakkestatus

## Kilde og original start
- URL: https://www.kaptajnkaper.dk/Kaper2.zip
- Arkiv-SHA256: `a9cf151351ad6e97f3d8f3bf338829b878df6bdeff6e190fbf3de8bbd7cf8732`.
- 10 spilfiler, DOS MZ KAPER.EXE; GO.BAT starter GRAFTDA2 og KAPER.
- Skærmtitel: Kaptajn Kaper i Kattegat, Version 1 Release 5.
- Python urllib fik HTTP 403; curl-download lykkedes og er brugt i opskriften.
- Originalfilerne er uændrede. Ingen Wine eller separat installer.
- Kilde-launcher: kort og F1-hjælp visuelt verificeret; brugeren bekræftede derefter at spillet virker som det skal og bad om ikke at teste mere.
- Fire isolerede opskriftstests bestod før brugerens stop af yderligere gameplay-test.

## AppImage — Version 1 Release 5 (1.5)
- Aktuel fil: `extras/dist/kaptajn-kaper-v1-release5-dos-x86_64.AppImage`.
- SHA256: `cb4452618ffdfde147eab46a44af067af0b85507019a210409b860e6b96851b9`.
- Programnavn og begge indbyggede desktop-filer viser Version 1 Release 5 (DOS); X-AppImage-Version=1.5.
- Indbygget proveniens angiver game_version=1, game_release=5, edition=ZIP/DOS.
- Alle spilfilers hash matcher den tidligere pakke. Kun mærkning/dokumentation ændret; ingen gameplay-gentest.
- Skrivebords- og menugenvej peger nu på den versionerede pakke. Gemmemappen er uændret.
- Den separate GitHub-kilde er Version 1 Release 3 (1.3); ingen Release 3-AppImage bygget endnu.

### Tidligere pakke, bevaret som rollback
- Fil: `extras/dist/kaptajn-kaper-2-x86_64.AppImage`.
- Størrelse: 35.255.488 bytes.
- SHA256: `4eb1fb3237a04d71cdba0c6ccbb5101f1e9cf8843a08b29a3e38a38a39a31d2e`.
- Bygget med repoets fælles Gys-downloadværktøjer og Harald-pakkemønster.
- DOSBox-Staging 0.83.0 (7b400) indbygget; eget genereret skibsikon.
- Færdig pakke udtrukket; begge desktop-filer, alle ikonplaceringer og AppRun kontrolleret.
- Alle 10 indbyggede spilfilers SHA256 matcher build-proveniens.
- Indbygget DOSBox `--version` kørte; AppRun består Bash-syntakskontrol.
- Ingen gentaget gameplay-test efter brugerens ønske. AppImage-spilstart, lyd og frisk/genbrugt spiltilstand er ikke interaktivt verificeret.
- Version-proben læste værtens standardkonfiguration og gav deprecated-advarsler; AppRun bruger eksplicit `-noprimaryconf -nolocalconf`, så dette er ikke pakkens startkonfiguration.
- Build-, cache-, runtime- og distributionsfiler holdes uden for Git. Kun opskrift, tests, bygge scripts og dokumentation indgår i spillets commit.
