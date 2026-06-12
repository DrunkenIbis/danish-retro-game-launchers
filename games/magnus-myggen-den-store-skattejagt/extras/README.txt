Magnus & Myggen: Den Store Skattejagt - Lutris local BIN/CUE wrapper

Projektmappe:
  /home/test/lutris_game_scripts_mm2

Filer:
  Magnus Myggen Den Store Skattejagt.lutris.yml  - Lutris lokal installer YAML
  magnus_myggen_store_skattejagt_launch.sh       - wrapper der udpakker zip/BIN/CUE og starter spillet
  magnus-myggen-den-store-skattejagt.zip         - original zip med MM2NORD.bin/cue

Vigtig rettelse:
  Den originale LAUNCHER.EXE starter InstallShield, men på denne Wine 11/Fedora opsætning fejler den med:
    Installationsprogrammet kunne ikke startes: 0x80070402
  Derfor bypasser wrapperen InstallShield og udpakker den danske MM2RUN.EXE manuelt fra DATA1.CAB.

Disc-inspektion:
  Zip indeholder MM2NORD.bin og MM2NORD.cue.
  CUE siger TRACK 01 MODE1/2352, så wrapperen konverterer BIN til en normal 2048-byte/sector ISO.
  AUTORUN.INF siger: open=launcher.exe
  LAUNCHER.EXE er kun installer/launcher; den stabile game-mode starter installed-dk/MM2RUN.EXE direkte.

Import i Lutris:
  lutris -i "/home/test/lutris_game_scripts_mm2/Magnus Myggen Den Store Skattejagt.lutris.yml"

Manuel test uden at starte spillet:
  MM2_DRY_RUN=1 /home/test/lutris_game_scripts_mm2/magnus_myggen_store_skattejagt_launch.sh

Start spillet direkte:
  /home/test/lutris_game_scripts_mm2/magnus_myggen_store_skattejagt_launch.sh

Nyttige overrides:
  MM2_MODE=game      standard; starter MM2RUN.EXE direkte
  MM2_MODE=launcher  prøver original LAUNCHER.EXE, men kan give 0x80070402
  MM2_MODE=setup     prøver original SETUP.EXE
  MM2_VIRTUAL_DESKTOP=1 er standard, fordi direkte MM2RUN-vindue på Wayland/Xwayland kan give lyd og proces uden synligt billede
  MM2_WINVER=win98 er standard, fordi MM2RUN.EXE er et Win95/98-era program og kan page-faulte under Wines Windows 10 default
  MM2_VIRTUAL_DESKTOP=0 kan prøves hvis Wine desktop giver problemer
  MM2_WINE_BIN=wine32 bruges som standard, hvis den findes
  MM2_CD_DRIVE=d mapper de udpakkede ISO-filer som Wine CD-ROM-drevet D:
