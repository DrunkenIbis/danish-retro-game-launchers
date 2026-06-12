#!/usr/bin/env bash
set -euo pipefail
WORK=/home/test/lutris_game_scripts_Magnus_Myggen_Leg_og_Laer
export WINEPREFIX=$WORK/wineprefix32
export WINEDEBUG=+loaddll,+seh
cd "$WORK/cdrom"
timeout 25s wine32 explorer /desktop=MagnusMyggenLegOgLaer,640x480 'd:\MAGNUS.EXE'
