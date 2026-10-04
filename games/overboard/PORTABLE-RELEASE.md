# Private portable delivery — host verified, Mint blocked

Artifact (outside Git):
`local/appimage-dist/overboard-portable-delivery/Overboard-KernelFree-Portable-x86_64.AppImage`

SHA-256:
`bcee8c326d92e842f3067078fcf54ed107a1efa570001b3bc789d1069f560689`

Knowledge checkpoint: `7392019`. The closing source commit containing this record
contains the packaging source used for these bytes; later README/release notes do
not change the artifact. No push or redistribution of commercial payload.

## Verified

- Build and exact artifact `--check` passed. The latter checks payload presence,
  not graphics/audio completeness.
- 40 Overboard tests and 7 shared Wine-runtime tests passed in the parent session.
- Exact artifact launched with fresh state and then the same preserved state.
  Default Wayland Gamescope -> Xwayland -> 16-bit Xephyr -> Wine path, no direct
  fallback. Single-player level selected deliberately; Right on the first run and
  Left on the second produced visible steering. Inner-display captures reviewed.
- Both runs recorded private Wine/wineserver, gamescopereaper, loader and libc
  mappings. Gamescope scripts loaded from the bundle. Host gamescopereaper was
  not used by the test; unrelated host processes were preserved.
- Exact-prefix wineserver cleanup completed and test mounts/processes disappeared.
  State retained. Original/reference and preceding artifacts were preserved.

Evidence: `local/runtime/overboard-delivery-evidence/result.json`, run logs,
process inventories, maps, screenshots and cleanup records. These local evidence
files are not game-source dependencies and are not committed.

## Boundaries / unresolved

**Not certified portable on arbitrary machines.** Mint 22.3 under QEMU TCG failed
with the earlier v4 GS/TLS crash; this delivery was not rerun in that VM and does
not claim to fix it. See `extras/mint-portable-test.md` and `PORTABLE-FINDINGS.md`.
Audio, normal in-game quit and final host-composited Wayland scaling/tearing remain
unverified for these bytes. Inner gameplay and prior user confirmation of the
source launcher are distinct evidence. Tests used an explicitly isolated state,
not the user's existing default state.

Kernel-free means no CDEmu/VHBA/optical medium required by the new game path; it
is not a claim of a bundled operating system. A compatible Linux x86_64 desktop,
host shell/kernel/display and graphics support remain required. Scope is 32-bit
Wine X11/GLX; winevulkan is disabled. Build remains prepared-seed/host-runtime based,
not fully pinned installation-from-media reconstruction.

## Packaging fixes retained

TOC/audio WinMM emulation with original EXE; dynamic 16-bit display sizing;
Wayland aspect-fit scaling; separate Wine/display Linux runtimes; prefix-link
sanitation including nested Templates; bundled Gamescope scripts and reaper;
Wine-specific graphics environment; explicit loader-relative Wine data paths;
startup deadlines; prefix locking and signal-safe descendant cleanup, including
libc pidfd fallback and reparenting discovery. Regressions cover these boundaries.

## Build / run

From repository root, with documented local seed/runtime inputs available:

```sh
DIST_DIR="$PWD/local/appimage-dist/<new-directory>" \
  bash games/overboard/extras/build_portable_appimage.sh
```

Run the artifact directly. Optional isolated writable state:

```sh
OVERBOARD_STATE="$HOME/.local/share/overboard-my-test" \
  ./Overboard-KernelFree-Portable-x86_64.AppImage
```

The builder also depends on the three shared runtime files under
`games/battlefield-1942/extras`: `portable_runtime.py`, `portable-wine`, and
`portable-packages.json`. They and their regression test are included explicitly
in the closing source commit; unrelated Battlefield launcher changes are not.
