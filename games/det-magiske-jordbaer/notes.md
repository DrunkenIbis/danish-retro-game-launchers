# Notes

Migrated from: `/home/test/lutris_game_scripts_DetMagiskeJordbaer`

Only top-level recipe files were moved. Runtime folders, ISOs, BIN/CUE images, extracted discs, Wine prefixes, logs, screenshots, bundled runners and installed game assets were intentionally left out of this Git-ready recipe tree.

## Verification notes

2026-06-12: The migrated wrapper initially still expected the ISO, `cdrom/`, `game/`, logs, and `det-magiske-jordbaer.conf` inside the game recipe directory. It has been updated to use the repo-local ignored layout by default:

- source ISO: `local/sources/det-magiske-jordbaer/DetMagiskeJordbaer.iso`
- runtime: `local/runtime/det-magiske-jordbaer/`
- generated DOSBox config: `local/runtime/det-magiske-jordbaer/det-magiske-jordbaer.conf`

A local symlink was created from `local/sources/det-magiske-jordbaer/DetMagiskeJordbaer.iso` to the old private ISO for testing. This path is ignored by Git.

Direct wrapper test reached DOSBox-Staging with the custom config loaded, mounted both generated runtime directories, and entered `VGA 320x200 256-colour graphics mode 13h`. The command timed out only because the game kept running, which is expected for this bounded smoke test.
