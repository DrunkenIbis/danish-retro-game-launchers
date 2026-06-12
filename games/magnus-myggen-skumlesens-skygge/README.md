# Magnus & Myggen: Skumlesens Skygge/Hævn

Status: recipe migrated from an existing local working/debug folder.  
Runner: wine

This directory contains only the compatibility recipe. It does not contain the game.

## Bring your own game files

Place your legally obtained game files in one of these locations:

```text
~/retro-game-files/magnus-myggen-skumlesens-skygge/
# or
local/sources/magnus-myggen-skumlesens-skygge/
```

See `recipe.yml` for expected metadata. Checksums still need to be filled in before publishing.

## Run

```sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime ./games/magnus-myggen-skumlesens-skygge/launch.sh
```

## Lutris

If `lutris.yml` exists, import it as a local Lutris install script/config. The wrapper remains the canonical entry point.

## Reference links

The recipe may include search/reference links only. Verify legal status and provide your own copy.
