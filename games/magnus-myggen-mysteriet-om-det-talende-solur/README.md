# Magnus & Myggen: Mysteriet om det talende solur

Status: user-confirmed working after the original InstallShield installation under Wine 11.0 Staging/win32/win98. The canonical launcher also exited normally (0). AppImage packaging is the next step.

## Install / launch

```sh
./games/magnus-myggen-mysteriet-om-det-talende-solur/install.sh --download
./games/magnus-myggen-mysteriet-om-det-talende-solur/launch.sh
```

The installer downloads checksum-pinned BIN/CUE media, converts the single MODE1/2352 track to ISO, extracts it, then opens the ORIGINAL InstallShield setup. For already downloaded media use `--existing`. `--no-launch` only prepares media; finish installation with `SOLUR_MODE=setup ./launch.sh`.

In setup: keep the default installation folder, choose Normal, deselect the old DirectX installer, finish the wizard. The tested installation lives at `C:\Program Files\IVANOFF Interactive\Mysteriet om det talende solur`. Do not replace the original install with manual CAB copying: a direct extracted mm6.exe showed `This trial game has expired.` before installation, while the original installer allowed the menu to open. No executable or licence patch was made, and no registry licence values are embedded in this recipe.

Dependencies: Bash, Python 3.11+, curl, 7z, wine32 + matching wineserver, flock. A native X11/Xwayland desktop is needed for Wine GUI.

Private files use `local/sources/magnus-myggen-mysteriet-om-det-talende-solur/` and `local/runtime/magnus-myggen-mysteriet-om-det-talende-solur/`. The Wine prefix is under runtime `prefix/`. Overrides: `SOLUR_SOURCE_DIR`, `SOLUR_RUNTIME_DIR`, `SOLUR_WINE_BIN`, `SOLUR_DESKTOP_SIZE` (800x600), `SOLUR_MODE` (game/setup), `SOLUR_DRY_RUN=1`. Repository-wide source/runtime base overrides are supported.

First Wine initialization initially timed out. Stopping only this title's wineserver and restarting it allowed prefix commands to work; this does not require deleting its prefix. The launcher reports initialization failure rather than silently treating a partial prefix as success.

## Verification and remaining work

- Archive.org size/SHA1 verified; installer pins SHA256 too.
- ISO extraction and original InstallShield installation completed.
- Launcher dry-run regression test and shell syntax passed.
- Canonical launcher visually reached the title screen; earlier original-installed launch reached the menu/new-game naming screen.
- Automated input initially did not advance beyond Start spil, but the user subsequently confirmed the game works as intended. This is not an unresolved gameplay/licence blocker.
- No full playthrough by the agent; no AppImage yet.

```sh
python3 games/magnus-myggen-mysteriet-om-det-talende-solur/extras/test_launcher.py
bash -n games/magnus-myggen-mysteriet-om-det-talende-solur/{install,launch}.sh
```

## Sources

- https://archive.org/download/magnus-myggen-mysteriet-om-det-talende-solur/M630DA.bin
- https://archive.org/download/magnus-myggen-mysteriet-om-det-talende-solur/M630DA.cue
- https://bibliotek.dk/materiale/magnus-myggen-mysteriet-om-det-talende-solur/work-of:870970-basis:23606658

Bibliotek.dk describes helping the residents of Paradisparken prepare for the unveiling of Molly's sundial, with activities concerning time. Media revision M630DA contains a 2008 installer; don't assume other releases have identical installation requirements.
