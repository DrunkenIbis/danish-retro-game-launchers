# Battlefield 1942 1.61b SiMPLE — private AppImage

Status: the exact AppImage has been user-confirmed into gameplay on both the first launch with a previously nonexistent default state and a second launch reusing that state. Fresh-run `/proc` evidence verified BOTH wine-preloader and wineserver from the AppImage mount. After each exit, no processes belonging to the exact test prefix remained and the corresponding AppImage mount disappeared. Physical media was absent and CDEmu empty. Both runs returned 1; the user reported good gameplay, but normal Quit intent was not separately stated for these runs. There is no independent agent gameplay screenshot of this variant: the owner explicitly requested proceeding on their visual/gameplay confirmation. Audio, long-term stability, other machines and cross-distro portability remain unverified.

Artifact:
`local/runtime/battlefield-1942/appimage-dist/Battlefield-1942-1.61b-SiMPLE-x86_64.AppImage`

Size at build: 1377936576 bytes. Companion .sha256 contains digest. PRIVATE: includes commercial game files, community patch and installer-created registration. Do not distribute or commit.

Build from repo root:

```sh
games/battlefield-1942/extras/build_appimage.sh
```

Builder uses `scripts/common.sh` and `scripts/wine-appimage-builder.sh`, the stopped gameplay-confirmed `simple161b/prefix-gameplay-verified` seed and the entire tested `lutris-GE-Proton7-43-x86_64` runner including matching wineserver. No CD image bundled; no CDEmu/VHBA requirement. Existing artifact is preserved by refusing overwrite; choose another ignored DIST_DIR for experimental rebuilds. Source changes are in extras/AppRun and extras/build_appimage.sh, not generated AppDir-only edits.

AppRun always selects bundle-relative Wine/wineserver; there is no host-Wine fallback. Writable prefix, saves and logs default to `${XDG_DATA_HOME:-$HOME/.local/share}/battlefield-1942-simple-appimage`. `BF1942_APPIMAGE_STATE=/absolute/path` selects isolated writable state. The seed is copied on first launch; do not interrupt merely because a multi-gigabyte first copy precedes the game window. Per-state locking covers seeding and Wine lifetime, with lock descriptor closed in Wine children. Copied optical mappings and absolute user-shell symlinks are removed from bundle seed. Runtime recreates c:/z: and does not mount images. BF1942_DEBUG controls Wine logging.

Runtime still depends on host Linux facilities and compatible 32-bit graphics/system libraries; cross-distro portability is not tested. Host commands include bash, flock, timeout, cp, chmod, mv, mkdir, ln, rm, mktemp and date. AppImage runtime normally uses FUSE. This is a Wine-bundled private game package, not proof of a universally standalone Linux environment.

Automated checks: AppRun rejects relative state before writes; source shell syntax passes. Exact artifact extraction confirms root/shared desktop entries, matching Icon basename, root/.DirIcon/hicolor PNGs, AppRun and bundled Wine/wineserver. Gameplay must be tested separately on the artifact.
