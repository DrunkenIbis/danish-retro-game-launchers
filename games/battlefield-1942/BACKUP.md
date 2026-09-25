# Originalmedie-backup

## CD 1: ufuldstændig sektorkopi, filområder dækket

Kilde: fysisk ASUS SDRW-08D2S-U via `/dev/sr0`, label `DISC_1_BF1942_1`. cd-info viser ét Mode 1-dataspor fra LBA 0 til leadout 321238; ingen lydspor. Format: cooked data ISO, 2048 bytes/sektor. Rå sektorer, subkanaler og kopibeskyttelsesdata er ikke bevaret af formatet.

Privat destination: `local/sources/battlefield-1942/backups/DISC_1_BF1942_1.iso` med tilhørende `.map`, `.toc.txt`, `.source.txt`, `.ddrescue.log`, `.report.json`, `.audit.json`, `.7z-test.txt`.

- Forventet og faktisk fillængde: 657895424 bytes.
- SHA-256: `5b052a596ee638d3bcd3a773e2d264c856f8b0294d807dac5ef6b0ff851ab4ec`.
- ddrescue exit 0, men opskriften returnerede korrekt 1, fordi sektorområdet ikke er fuldt læst.
- Mapstatus i bytes: recovered `+` 638951424; bad `-` 65536; untrimmed `*` 446464; untried `?` 18219008; unscraped `/` 212992.
- Dette er en ufuldstændig rescue-ISO, ikke en fuldstændig arkivbackup. Fillængde og hash beviser ikke de manglende sektorers integritet.
- Battlefield Vietnams audit-rescue-iso.py kontrollerede 444 poster på tværs af primary-16, primary-17 og joliet-18: ingen fil-, mappe- eller path-table-poster overlapper manglende læsedækning. Poster er ikke unikke filer.
- `7z t` returnerede 0, Everything is Ok, 121 filer og 24 mapper. Dette viser filsystemets læsbarhed, ikke fuld sektor-/kopibeskyttelsesintegritet. VolumeSpaceSize er 657588224; hele TOC-baserede fillængde er bevaret.
- Der er ikke dokumentation for, at de ulæselige områder er tilsigtede beskyttelsessektorer. Det må ikke udledes alene af placeringen uden for de auditerede filområder.
- Ingen diskfri gameplay-test er udført med denne ISO. Bevar første image og map før eventuelle yderligere recovery-forsøg. Undgå gentagne belastende genlæsninger, før der er konkret behov.

## Reproduktion

Fra projektroden, korrekt original-CD indsat:

```sh
games/battlefield-1942/backup-disc.sh DISC_1_BF1942_1
# Efter verificeret diskskift:
games/battlefield-1942/backup-disc.sh DISC_2_BF1942_2
```

Scriptet genbruger scripts/common.sh og Battlefield Vietnams backupmønster. Afviser forkert label, ikke-optisk enhed, andet end et enkelt Mode 1-dataspor fra LBA 0 samt eksisterende backupfiler. Standardkilde er /dev/sr0, override BF1942_DEVICE; værktøj BF1942_DDRESCUE. Eksisterende lokal ddrescue 1.30 fra Global Operations bruges, hvis ddrescue ikke er i PATH; ingen systeminstallation foretages. Shell-syntaks og afvisning af ugyldigt label er testet; real-media CD 1-resultatet er som ovenfor.

## CD 2

Kilde: fysisk `/dev/sr0`, label `DISC_2_BF1942_2`, verificeret før kopiering. Backupscriptets TOC-gate accepterede ét Mode 1-dataspor fra LBA 0. Cooked ISO, forventet og faktisk størrelse 681357312 bytes. SHA-256: `946b25943b51cb55c279567bcaf9c6e21a819f29290f53d5eba431a54976dd85`.

Mapstatus i bytes: recovered `+` 662761472; bad `-` 100352; untrimmed `*` 698368; untried `?` 17432576; unscraped `/` 364544. ddrescue exit 0, opskrift exit 1: også denne rescue-kopi er ufuldstændig. Ingen påstand om rå kopibeskyttelses-/subkanalintegritet.

Audit kontrollerede 420 poster på tværs af primary-16, primary-17 og joliet-18, uden manglende læsedækning i fil-, mappe- eller path-table-poster. `7z t`: exit 0, Everything is Ok, 114 filer og 23 mapper. VolumeSpaceSize 681050112; fuld TOC-baseret fillængde bevaret. Der er ikke påvist fejl i de auditerede filområder, men manglende sektorer udenfor dem består.

Privat image og rapporter ligger ved siden af CD 1 med basename `DISC_2_BF1942_2`. Den tidligere CAB/Support/eReg-staging under runtime bevares som installationshjælp. Begge originalmediers første rescue-forsøg bevares uden yderligere recovery-overwrites. Diskfri gameplay er endnu ikke testet.
