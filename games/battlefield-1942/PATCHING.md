# Official retail 1.61b isolated update

Status: ejeren bekræfter patchinstaller afsluttet med succes; procesexit 0. Efterfølgende filhash-kontrol viser ændrede BF1942.exe, BF1942_w32ded.exe, Mods/bf1942/contentCrc32.con og Mods/bf1942/init.con. Sidstnævnte angiver nu `game.setCustomGameVersion 1.61`. MultiplayerServers/ASEHost.dll, GameSpyHost.dll, GameSpyJoin.dll, GameSpyKeyMap.ini og GameSpyLanJoin.dll blev fjernet; ingen nye filer registreret. Før/efter-manifests ligger privat i logs. Patchpakken er 1.61b; spillets egen modversion skrives 1.61. Fysisk-CD-kontrol af den opdaterede kopi er startet med CD 1 på /dev/sr0 og CDEmu tomt. Ejeren har nu bekræftet, at den opdaterede version virkede som den skulle under den fysiske CD-test. Procesexit var 1; normal Quit er ikke særskilt bekræftet i denne tilbagemelding. Paired wineserver -w er afsluttet, og det stoppede prefix er bevaret som `official161b/prefix-gameplay-verified`. Agenten har ikke fået et særskilt gameplay-screenshot fra den opdaterede version. Diskfri kørsel for denne version er endnu IKKE verificeret.

The owner confirmed the same `cdemu-vanilla16` test prefix reached gameplay with the physical original and was quit normally. The rescue ISO/CDEmu test exited by itself before verified menu/gameplay. This distinguishes media presentation from general prefix viability, but does not prove the precise reason or implicate unread sectors alone.

## Source

Reference: https://community.pcgamingwiki.com/files/file/999-battlefield-1942-incremental-patch-1619-to-161b/ identifies the official retail incremental patch and requires 1.6.19. Direct HTTP retrieval of that page returned 403; its descriptive content was accessible through web extraction.

Mirror page: https://www.skullsquadron1.com/Downloads/Games/Battlefield/Battlefield-1942/Battlefield%201942.htm
Download: https://www.skullsquadron1.com/Downloads/Games/Battlefield/Battlefield-1942/Patches/bf1942_v1.6_to_v1.61b.exe

Local private file: `local/cache/battlefield-1942/patches/bf1942_v1.6_to_v1.61b.exe`, 6720809 bytes, SHA-256 `895b7446ec7aae9e917b49eed7232155aa80b6d5a9b42a44f782e0857a4943c0`. PE32 InstallShield self-extracting CAB; `7z t` passed all 11 contained files. This is an archive-integrity result, not independent cryptographic authentication by EA.

## Isolated application

Seed: `local/runtime/battlefield-1942/physical-vanilla-retry/prefix-gameplay-verified`. Sibling wineserver -w completed before copying to new `local/runtime/battlefield-1942/official161b/prefix`. No writes to seed. Before-patch SHA-256 manifest covers 190 installed files in private `official161b/logs/before-patch-hashes.json`.

Same GE-Proton7-43 runner, win32/winxp seed, WINEDEBUG=-all, unset inherited WINEARCH/WINEDLLOVERRIDES/WINEDLLPATH. Installer launched from patch cache directory, with paired wineserver wait afterward. Do not infer installed patch from process exit alone; inspect final dialog and compare hashes/version.

Baseline Mods/bf1942/init.con says 1.6 and selective registry language readback says English. Exact 1.6.19 build has not been independently established; the incremental installer's own compatibility check is being tested only in the disposable copy. If rejected, inspect required full update rather than force patching. This patch is not claimed to remove retail CD protection.
