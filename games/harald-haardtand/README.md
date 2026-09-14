# Harald Hårdtand: Kampen om de rene tænder

Status: user-confirmed working on Linux. First-level movement and shooting visually verified with DOSBox-Staging 0.83.0. Baseline emulator exited normally (0). Full playthrough not tested.

## Install and play

```sh
./games/harald-haardtand/install.sh --archive /path/to/HaraldHaardtand.zip --no-launch
./games/harald-haardtand/launch.sh
```

Requires Python 3.11+ and DOSBox-Staging (native or Flatpak `io.github.dosbox-staging`). No Wine or Windows DOSBox is used. Only the five required DOS game files are extracted; TRAIN.EXE is not used. The supplied archive is checksum-pinned, not downloaded or redistributed.

Defaults: normal CPU core, 6000 cycles, 16 MB RAM, SB16, 48 kHz mixer with 1024-sample blocks and 80 ms prebuffer. `HARALD_CPU_CYCLES` overrides cycles (1000–100000). `HARALD_DOSBOX_BIN` selects a native Staging executable. `HARALD_DRY_RUN=1` prepares and prints the command without opening a window.

Private archive: `local/sources/harald-haardtand/HaraldHaardtand.zip`.
Writable game/highscores: `local/runtime/harald-haardtand/game/` (`HIGH.DAT` is preserved on reinstall).
Overrides: `HARALD_ARCHIVE`, `HARALD_SOURCE_DIR`, `HARALD_RUNTIME_DIR`, or repository-wide `RETRO_GAME_SOURCE_DIR` / `RETRO_GAME_RUNTIME_DIR`.

Menu: 1 starts one player; 4 displays instructions. Arrows move, Space fires. Alt+Enter toggles fullscreen; Ctrl+F9 exits DOSBox.

## Verification

```sh
python3 games/harald-haardtand/extras/test_recipe.py
bash -n games/harald-haardtand/{install,launch}.sh
```

Two regression tests cover extraction allowlist, checksum rejection, preserving highscores, paths containing spaces, generated config and cycle validation. Local archive installation and shell syntax checks passed.

AppImage: not yet packaged.

## References

- https://danskedosklassikere.blogspot.com/2016/01/harald-hardtand.html
- https://www.myabandonware.com/game/harald-haardtand-kampen-om-de-rene-taender-1f8/play-1f8
