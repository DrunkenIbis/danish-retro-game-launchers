Den Lyserøde Panter - Lutris lokal ISO wrapper

Filer:
- Den Lyseroede Panter.lutris.yml: importeres i Lutris.
- pink_panther_launch.sh: wrapper som udpakker ISO'en, initialiserer en win32 Wine-prefix, mapper ISO'en som D:-CD-ROM og starter spillet.
- Den Lyserøde Panter på hemmelig mission i udlandet.iso: original ISO.
- game-files/: udpakket ISO.
- wineprefix32/: lokal Wine-prefix.

Import i Lutris:
  lutris -i "/home/test/lutris_game_scripts_Pink_panter/Den Lyseroede Panter.lutris.yml"

Hvis spillet allerede er importeret, kan det startes med fx:
  lutris lutris:rungameid/5

Aktuel løsning:
- SETUP.EXE på ISO'en er en 16-bit Windows 3.1 installer.
- Spillets reelle executable er INSTALL/PPTP.EXE, men INSTALL-mappen indeholder gamle system-DLL'er som VERSION.DLL, COMDLG32.DLL, SHELL32.DLL og WINSPOOL.DRV.
- Hvis PPTP.EXE startes direkte fra INSTALL, shadow'er de gamle DLL'er Wine's egne DLL'er og giver c000007b / import-dll fejl.
- Wrapperen bruger derfor PP_LAUNCH_MODE=installed som standard.
- Den laver en manuel clean install til:
  /home/test/lutris_game_scripts_Pink_panter/wineprefix32/drive_c/Program Files/Pink Panther
- Under clean install udelades gamle Windows/Win32s systemfiler, så Wine bruger sine egne DLL'er.

Debug/test:
  PP_PREPARE_ONLY=1 /home/test/lutris_game_scripts_Pink_panter/pink_panther_launch.sh
  PP_INSTALL_ONLY=1 /home/test/lutris_game_scripts_Pink_panter/pink_panther_launch.sh
  PP_VIRTUAL_DESKTOP=0 /home/test/lutris_game_scripts_Pink_panter/pink_panther_launch.sh

Alternative modes:
  PP_LAUNCH_MODE=installed  # standard, anbefalet
  PP_LAUNCH_MODE=cdexe      # direkte fra INSTALL/PPTP.EXE, forventes at fejle pga. gamle DLL'er
  PP_LAUNCH_MODE=setup      # gammel 16-bit installer
  PP_LAUNCH_MODE=teaser     # autorun teaser.exe

Bemærkning:
Første fejl under debugging var en halvfærdig Wine-prefix uden drive_c/windows/system32. Wrapperen flytter nu sådan en prefix til wineprefix32.broken.TIMESTAMP og initialiserer Wine før D:-CD-ROM mapping.
