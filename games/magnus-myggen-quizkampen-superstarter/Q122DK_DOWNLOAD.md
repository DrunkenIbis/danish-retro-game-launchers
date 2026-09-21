# Q122DK downloadudgave: brugerbekræftet gameplay

Den eksisterende `Quizkampen Superstarter Version.iso` fra den dokumenterede
Archive.org-reference virker efter original installation. Den tidligere
manuelle CAB-udpakning var ikke en tilstrækkelig installation; dens fejl er
ikke bevis for, at hele mediet er en ubrugelig demo.

## Verificeret forløb

- `7z t` bestod; label Q122DK, 31531008 bytes.
- SHA-256: `0346759d435612e2c05170deab203402fae92e2345833dca98a69fb6afb61ae9`.
- Nyt prefix: `local/runtime/magnus-myggen-quizkampen-superstarter/download-q122dk-ge-original-setup/wineprefix32`.
- Wine-GE `local/runners/lutris-GE-Proton7-43-x86_64`, win32 og Windows 98.
- ISO indlæst i ledigt CDEmu device 1, `/dev/sr2`, monteret på `/run/media/test/Q122DK`.
- Prefix D: peger på dette mountpoint, D:: på dette virtuelle blokdrev;
  Wine Drives `d:` er `cdrom`. Andre optiske Wine-mappings blev fjernet.
- Original `D:\setup.exe` gennemført af brugeren med standardplacering.
- Ingen Q112DK-spilfiler, registrering, licensværdier eller EXE-patches overført.
- Start af installeret `C:\Program Files\IVANOFF Interactive\Quizkampen\mm12main.exe`
  i 800×600 Wine-desktop nåede direkte til spillermenuen uden gammel modal.
- Brugeren bekræftede derefter: “det virker også som det skal”. Exitkode 0.

## Gentag start i den eksisterende installation

Fra repoets rod, med den samme download-ISO monteret og D:/D:: kontrolleret:

```sh
ROOT="$PWD"
export WINEPREFIX="$ROOT/local/runtime/magnus-myggen-quizkampen-superstarter/download-q122dk-ge-original-setup/wineprefix32"
export WINEARCH=win32 WINEDEBUG=-all WINEDLLOVERRIDES='mscoree,mshtml='
GE="$ROOT/local/runners/lutris-GE-Proton7-43-x86_64"
cd "$WINEPREFIX/drive_c/Program Files/IVANOFF Interactive/Quizkampen"
"$GE/bin/wine" explorer /desktop=QuizkampenDownload,800x600 'C:\Program Files\IVANOFF Interactive\Quizkampen\mm12main.exe'
"$GE/bin/wineserver" -w
```

Virtuelle device-numre og mountpoints kan ændres. Kontroller `cdemu status`,
`cdemu device-mapping` og `findmnt` før genbrug; overskriv ikke optagne drev.
Denne dokumentation er den testede manuelle vej, ikke en ny automatisk installer.
Den gamle `launch.sh` bruger stadig CAB-only-metoden og bør ikke bruges som
bevis på eller indgang til den nye fungerende installation.

## Afgrænsning

Q112DK-AppImage er fortsat den eneste byggede og brugerbekræftede AppImage.
Der er ikke bygget eller testet en Q122DK-AppImage. Ingen ændring af den
fungerende Q112DK-installation eller pakke. Spildata og Wine-prefix forbliver
private og uden for Git. Downloadreferencen er bevaret i README og recipe.yml.
