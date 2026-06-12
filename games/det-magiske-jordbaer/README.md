# Det Magiske Jordbær

Status: recipe migrated from an existing local working/debug folder.  
Runner: dosbox-staging

This directory contains only the compatibility recipe. It does not contain the game.

## Bring your own game files

Place your legally obtained game files in one of these locations:

```text
~/retro-game-files/det-magiske-jordbaer/
# or
local/sources/det-magiske-jordbaer/
```

See `recipe.yml` for expected metadata. Checksums still need to be filled in before publishing.

## Run

```sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime ./games/det-magiske-jordbaer/launch.sh
```

## Lutris

If `lutris.yml` exists, import it as a local Lutris install script/config. The wrapper remains the canonical entry point.

## Reference links

The recipe may include search/reference links only. Verify legal status and provide your own copy.
