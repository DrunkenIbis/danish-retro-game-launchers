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

Legend: ✅ = script exists in the recipe and is the current working/migrated path; — = not added yet.

| Game | Installer script | Launch script | AppImage script |
|---|---:|---:|---:|
| Battle Beast | — | ✅ | — |
| Den Lyserøde Panter: Hokus Pokus Panter | ✅ | ⚠️ Visible Wine game scene; manual playthrough not verified | ✅ |
| Det Magiske Jordbær | ✅ | ✅ | ✅ |
| Gys på Regneslottet | — | ✅ | — |
| Magnus & Myggen: Den Store Skattejagt | ✅ | ⚠️ Centered Wine desktop; gameplay not screenshot-verified | — |
| Magnus & Myggen: Leg og Lær | — | ✅ | ✅ |
| Magnus & Myggen: Quizkampen Superstarter | ✅ | ⚠️ SuperStarter/licens-stop | — |
| Magnus & Myggen: Skumlesens Skygge/Hævn | — | ✅ | — |
| Pink Panther: Passport to Peril | — | ✅ | — |
| Pyrus | — | ✅ | — |
| Uden at prale, det er Harry | ✅ | ✅ | ✅ |
| Yo! Joe! Beat the Ghosts | — | ✅ | — |

