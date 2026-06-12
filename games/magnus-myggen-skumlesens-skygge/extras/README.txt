Magnus & Myggen: Skumlesens Hævn - Lutris local ISO wrapper

Projektmappe:
  /home/test/lutris_game_scripts_mm2

Filer:
  Magnus Myggen Skumlesens Haevn.lutris.yml  - Lutris lokal installer YAML
  magnus_myggen_2_launch.sh                  - wrapper der udpakker ISO og starter spillet
  Magnus-Myggen-Skumlesens-Skygge.iso        - symlink til ISO'en i /home/test/Hentet

ISO-inspektion:
  AUTORUN.INF siger: open=launcher.exe
  LAUNCHER.EXE er PE32 Win32 GUI.
  SETUP.EXE er en Win16/NE installer, så den bruges ikke som standard.

Import i Lutris:
  1. Åbn Lutris.
  2. Tryk + / Add Game.
  3. Vælg "Install from a local install script".
  4. Vælg filen:
     /home/test/lutris_game_scripts_mm2/Magnus Myggen Skumlesens Haevn.lutris.yml

Alternativt fra terminal:
  lutris -i "/home/test/lutris_game_scripts_mm2/Magnus Myggen Skumlesens Haevn.lutris.yml"

Test uden at starte spillet:
  MM2_DRY_RUN=1 /home/test/lutris_game_scripts_mm2/magnus_myggen_2_launch.sh

Nyttige overrides:
  MM2_DESKTOP_SIZE=640x480 eller 1024x768
  MM2_VIRTUAL_DESKTOP=0 for at starte uden Wine virtual desktop
  MM2_WINE_BIN=wine32 bruges som standard, hvis den findes
  MM2_FORCE_WIN32=1 bruges som standard for et win32-prefix
  MM2_CD_DRIVE=d mapper de udpakkede ISO-filer som Wine CD-ROM-drevet D:
  MM2_RUN_INSTALLER=1 starter den originale installer i stedet for den manuelle installation
