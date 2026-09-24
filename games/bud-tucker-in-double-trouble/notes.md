# Verification notes

## Evidence boundaries

- Physical CD: user completed original DOS sound setup and Full installation. Agent inspected supplied screenshots including the bedroom gameplay screen. User confirmed interaction, speech/music/effects and normal exit.
- Folder: separate copied installation, extracted unchanged CD files presented as ordinary D: directory. User confirmed gameplay/audio and normal exit/automatic DOSBox closure. No separate agent gameplay screenshot for this branch.
- AppImage: exact final file tested twice, first with a previously absent state directory and then the same existing directory. User confirmed gameplay/audio and normal closure both times. Each process exited 0. Bundled native DOSBox process path verified on first run. Agent did not visually inspect an AppImage gameplay screenshot.
- Cleanup after second run: no DOSBox processes or Bud AppImage mounts remain, no optical mount/loop device, CDEmu empty. User confirmed normal exit rather than assuming it from process notification.
- No save/load test, full playthrough, long-duration stability test or other-distribution test.

## Immutable tested artifact

File: `extras/dist/Bud-Tucker-in-Double-Trouble-x86_64.AppImage`
Size: 526763200 bytes.
SHA-256: `049defabafea574c8ebd9420cc6c39aa6a09383836d725737b5224f839947c9d`

Fresh-state log: `local/runtime/bud-tucker-in-double-trouble/appimage-test-state/logs/game-20260924-083918.log`.
Repeat-state log: `local/runtime/bud-tucker-in-double-trouble/appimage-test-state/logs/game-20260924-104021.log`.

The tested file was not rebuilt merely to incorporate later verification prose. Its bundled README is an earlier build snapshot; repository README/notes hold current results.

## Automated checks

`python3 games/bud-tucker-in-double-trouble/test_recipe.py -v`: five tests passed. Synthetic fixtures exercise fresh-state seeding, preservation on repeated launch, overlap locking, incomplete-state rejection, relative-state rejection and missing folder-runtime diagnostics. These tests do not emulate or verify gameplay.

Shell syntax and Python compilation passed. Final AppImage extracted metadata verified both desktop files, basename-only Icon, root PNG/.DirIcon and hicolor PNG. Bundled DOSBox reports 0.83.0 (7b400). Runtime AppRun contains no absolute development paths. Build tools and native DOSBox tarball hashes are pinned by existing project helpers; provenance includes source/game hashes inside the private package.

Existing unrelated Git modifications were present before work began. Repository-wide whitespace inspection reports pre-existing whitespace in Skumlesens Hævn; that file is intentionally untouched by this task. Commit staging must include only Bud Tucker recipe files and its single main-index row, not other outstanding main-index additions.

## Reproduction

1. Mount the owner's BUD_USA CD read-only; run `install.sh`, choose SB16 automatic detection, Full installation to C:\TUCKER. Run `bud`, test, close normally and type `exit`.
2. Inspect TOC with cd-info. Run backup_cd.py with the output path shown in README; run 7z t. Preserve the original stopped runtime before experimenting.
3. Run `launch.sh prepare`; safely remove the original disc, ensure no optical/loop/CDEmu fallback, then run `launch.sh`. Test before packaging.
4. Close the folder launcher, run `extras/build_appimage.sh`. Test the final artifact with fresh and existing BUD_APPIMAGE_STATE directories. Never package a running mutable installation.

No Wine, copy-protection patch, fabricated registration, system package installation, kernel module change or reboot was used. Public recipe contains no original game files.
