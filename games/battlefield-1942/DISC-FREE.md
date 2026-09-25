# Diskfri vanilla 1.6: isolerede forsøg

Originalens gameplay-bekræftede prefix er bevaret under `local/runtime/battlefield-1942/physical-vanilla-retry/prefix-gameplay-verified`. Hver test bruger en separat kopi lavet efter paired wineserver -w. Ingen spil-EXE ændret, ingen opdatering installeret.

## A: installerede filer uden medie

Runtime: `local/runtime/battlefield-1942/folder-vanilla16`. Gamle optiske dosdevices-links fjernet i kopien; Wine genskabte d::/e:: til de tomme drev ved start. Fysisk `/dev/sr0` status 2 (åben skuffe), CDEmu device 0 tomt, ingen ISO9660/UDF-mounts. Agenten så og fotograferede `Cannot locate the CD-ROM` / `Please insert the correct CD-ROM, select OK and restart application`. Ingen gameplay. Kun testprefix stoppet via dets paired wineserver.

## B: lokale CD-filer mappet som D:

Runtime: `local/runtime/battlefield-1942/mapped-vanilla16`. CD 1 rescue-ISO udpakket med 7z til privat cdrom; lokal .windows-label `DISC_1_BF1942_1`; D: mappet til denne mappe og Wine Drives/d: sat til cdrom. Ingen image mount. Efter start D: stadig lokal mappe, optiske e::/f:: var auto-opdagede tomme drev. Samme CD-dialog visuelt verificeret. Ingen gameplay. Testprefix stoppet og wineserver afsluttet. Dette var en mappet-fil-test, ikke en loop-mount-test.

## C: original rescue-ISO i eksisterende CDEmu

Runtime: `local/runtime/battlefield-1942/cdemu-vanilla16`. CDEmu device 0 var verificeret tomt før `cdemu load 0 <repo>/local/sources/battlefield-1942/backups/DISC_1_BF1942_1.iso`. Device-mapping læst tilbage: `/dev/sr1`. lsblk identificerede CDEmu og korrekt label; automount `/run/media/test/DISC_1_BF1942_1`, findmnt bekræftede /dev/sr1 og read-only ISO9660. D: og D:: sat til dette mount og /dev/sr1; efter Wine-start er begge links verificeret. Fysisk ASUS /dev/sr0 fortsat status 2. E:: auto-opdaget til tomt fysisk drev.

Spillet afsluttede af sig selv med exit 0; ejeren bekræftede ikke at have gjort noget. Intet gameplay eller menu er verificeret. Første log var tom. En gentagelse med `WINEDEBUG=+seh,+loaddll` afsluttede igen med exit 0. Loggen viser håndterede privileged-instruction/access-violation-undtagelser, efterfulgt af unload af `mods/BF1942/Mod.dll`. Dette er ikke alene bevis for et ubehandlet crash eller for at mediet blev accepteret. Næste diagnostiske kontrol er samme testprefix med fysisk original-CD, uden grafik-/runnerændringer, for at skelne medierepræsentation fra prefix-/modulinitialisering.

Paired wineserver er afsluttet. Testens /dev/sr1 blev unmountet og CDEmu device 0 unloadet. Første umiddelbare status var stadig loaded; efterfølgende read-back bekræftede tom enhed og ingen mount/label. Ingen systempakker eller kernelmoduler ændret.

## Opdateret 1.61b: diskfri forsøg

Efter brugerbekræftet fysisk-CD-gameplay og afsluttet wineserver blev `official161b/prefix-gameplay-verified` kopieret separat til folder161b, mapped161b og cdemu161b.

- Folder161b: fysisk drev status 2, CDEmu tomt, ingen optiske mounts; installerede filer alene giver visuelt verificeret CD-dialog. Testen stoppet af agenten, exit 1.
- Mapped161b: lokale CD 1-filer som D:, cdrom-type og label læst som DISC_1_BF1942_1; samme visuelt verificerede CD-dialog. Testen stoppet af agenten, exit 1.
- Cdemu161b: rescue-ISO i tidligere tomt device 0, read-back /dev/sr1 og read-only mount; D:/D:: verificeret efter launch, fysisk /dev/sr0 stadig status 2. Proces afsluttede med 0 uden verificeret menu/gameplay. Log viser samme access-violation/unwind og unload af Mod.dll som 1.6. Exitkode er ikke en succes. En identisk gentagelse i samme prefix med samme +seh,+loaddll-logning afsluttede også med exit 0. Ejeren observerede en sort firkant, der kort blinkede frem og lukkede af sig selv; ingen menu eller gameplay. Gentagelsens log er `cdemu161b/logs/game-cdemu-user-recheck.log`. Agenten stoppede ikke denne start. Efter ejerens observation er wineserver afsluttet, mediet unmountet/unloadet og CDEmu aflæst tomt igen.

Cdemu161b wineserver er afsluttet, forsøgets mount unmountet og CDEmu unloadet. Efterfølgende status bekræfter device 0 tomt og ingen optical label/mount. Begge versioner er fortsat kun gameplay-bekræftet med fysisk CD; ingen diskfri launcher/AppImage er verificeret.

Alle logs/screenshots ligger under de respektive private runtimes. CDEmu-start eller fravær af en fejl er ikke bevis for fungerende gameplay; rescue-ISO'ens manglende sektorer er fortsat dokumenteret i BACKUP.md.
