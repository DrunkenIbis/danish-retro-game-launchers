Battle Beast / Lutris

Filer i denne mappe:
- BEAST.iso
- launch_battle_beast.sh
- battle_beast_launch_and_install.sh
- Battle Beast.lutris.yml
- Battle Beast Installer.lutris.yml
- Battle Beast Robust.lutris.yml

Anbefalet version:
- Battle Beast Robust.lutris.yml
- battle_beast_launch_and_install.sh

Hvad den robuste version gør:
- Udpakker ISO’en ved første kørsel
- Opretter et 32-bit Wine-prefix
- Bruger wine32, så den gamle 7th Level-installer kan starte
- Kører SETUP.EXE første gang
- Starter derefter spillet via en passende launcher, typisk WIN95/LAUNCH.EXE
- På senere startere springer den setup over

Sådan bruger du den:
1. Gør scriptet eksekverbart:
   chmod +x /home/test/lutris_game_scripts/battle_beast_launch_and_install.sh
2. Importér /home/test/lutris_game_scripts/Battle Beast Robust.lutris.yml i Lutris som en lokal konfiguration, eller peg et lokalt spil på scriptet.
3. Sørg for at BEAST.iso ligger i samme mappe.

Teststatus i dette miljø:
- YAML-parsing: ok
- ISO-indhold: ok
- Udpakning af ISO: ok
- Selve Lutris/Wine-kørslen kunne ikke testes, fordi de ikke er installeret her.

Hvis du vil, kan jeg også lave en version, der prøver at finde den rigtige launch-fil automatisk efter SETUP.EXE har kørt og gemmer den som en .desktop-genvej.
