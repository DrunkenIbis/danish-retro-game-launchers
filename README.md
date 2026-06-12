# Retro Game Launchers

Compatibility recipes for running old Windows, DOS, and Windows 3.x games on Linux using Wine, DOSBox-Staging and Lutris.

This repository is intended to contain only recipes:

- launch wrappers
- Lutris installer/config files
- DOSBox configs
- install and troubleshooting notes
- small compatibility helper scripts
- metadata/checksums/reference links

This repository must not contain game files, CD/DVD images, cracks, serials, no-CD patches, Wine prefixes, extracted discs, installed game directories, or large runtime/build artifacts.

## Layout

```text
games/<game-id>/
  README.md
  recipe.yml
  launch.sh              # when a canonical launcher is known
  lutris.yml             # when a canonical Lutris recipe is known
  notes.md
  extras/                # original/alternate configs or helpers

templates/
  wine-iso/
  dosbox/
  windows-3x-dosbox/

docs/
  setup.md
  legal.md
  lutris.md
  wine.md
  dosbox.md
  troubleshooting.md
```

## Local private files

Put your own legally obtained game files outside Git. Recommended:

```text
~/retro-game-files/<game-id>/
~/retro-game-runtime/<game-id>/
```

Or, for local work inside this checkout, use ignored folders:

```text
local/sources/<game-id>/
local/runtime/<game-id>/
local/logs/<game-id>/
```

Most wrappers should support:

```sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime ./games/<game-id>/launch.sh
```

## Current migrated recipes

| Game | Runner | Status | Notes |
|---|---|---|---|
| Battle Beast | Wine/wine32 | recipe migrated | old Win95/Win16-adjacent setup |
| Det Magiske Jordbær | DOSBox-Staging | recipe migrated | local DOSBox wrapper |
| Gys på Regneslottet | DOSBox-Staging | recipe migrated | local DOSBox wrapper |
| Magnus & Myggen: Leg og Lær | Wine/winevdm | recipe migrated | Win16 Director, NE heap/prefix notes |
| Magnus & Myggen: Den Store Skattejagt | Wine | recipe migrated | manual-install style wrapper |
| Magnus & Myggen: Skumlesens Skygge/Hævn | Wine | recipe migrated | IVANOFF/InstallShield notes |
| Pink Panther: Passport to Peril | Wine/ScummVM notes | recipe migrated | clean install notes |
| Pyrus | Wine | recipe migrated | intro/video/DirectShow notes |
| Uden at prale, det er Harry | Wine | recipe migrated | Director/Inno notes |
| Yo! Joe! Beat the Ghosts | DOSBox-Staging | recipe migrated | DOS wrapper |

