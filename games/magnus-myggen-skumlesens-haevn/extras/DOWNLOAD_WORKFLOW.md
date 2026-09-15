# Downloaded media → original installation → self-contained AppImage

## Verified result

The cached Archive.org BIN/CUE files were validated against live Archive.org metadata before this test. The converted ISO was byte-identical (SHA256) to the ISO read from the user's physical M322DK CD. A **new empty Wine prefix** was initialized; no prefix, registration state or installed files were copied from the working physical-CD setup. The original installer completed from the extracted downloaded image. The resulting AppImage reached the first room and the user confirmed it worked.

The download-based package is separate from the older local-copy package:

`local/appimage-dist/mm3-download/magnus-myggen-skumlesens-haevn-x86_64.AppImage`

It includes original installed state, CD data and Wine-GE. The external ISO/BIN/CUE files are build inputs only, not runtime requirements. Game executables are unchanged.

## 1. Obtain and validate the media

Archive.org supplies BIN/CUE, not a directly downloadable ISO:

- https://archive.org/download/magnus-myggen-skumlesens-haevn/M322DK.bin
- https://archive.org/download/magnus-myggen-skumlesens-haevn/M322DK.cue
- Metadata: https://archive.org/metadata/magnus-myggen-skumlesens-haevn

Verified metadata:

| File | Bytes | SHA1 |
|---|---:|---|
| M322DK.bin | 343086240 | cf211c9c3979fcb7a7d19f9095e4fb248314d1aa |
| M322DK.cue | 72 | 81fcfa58dd5858c9e9cb8bfb165a8b2bb30c5a8c |

Store them privately under `local/sources/magnus-myggen-skumlesens-haevn/`. Reuse a cached file only after checksum validation. Download to a temporary filename, validate, then rename; do not overwrite a known-good source during a failed download.

The CUE describes one MODE1/2352 track. Convert by writing bytes 16 through 2063 of every complete 2352-byte sector as a 2048-byte ISO sector. Reject incomplete sectors rather than silently truncating. The result must be 298741760 bytes, SHA256:

`80907afb3136a6bfe02d3046d6a1e949c7c776a3b447ce326c04b54e0f61f4d9`

## 2. Install normally, not via manual CAB payload copying

From the repository root, with `local/runtime/mm3-download-install/prefix-ge` **absent**:

```sh
mkdir -p local/runtime/mm3-download-install/logs
7z x -y -olocal/runtime/mm3-download-install/cdrom local/sources/magnus-myggen-skumlesens-haevn/M322DK.iso
export WINEPREFIX="$PWD/local/runtime/mm3-download-install/prefix-ge"
export WINEARCH=win32 WINEDEBUG=-all WINEDLLOVERRIDES='mscoree,mshtml='
WINE="$PWD/local/cache/mm3-physical-cd/runner/lutris-GE-Proton7-43-x86_64/bin/wine"
timeout 60 "$WINE" wineboot -u
"$WINE" reg add 'HKCU\Software\Wine' /v Version /d win98 /f
ln -sfn "$PWD/local/runtime/mm3-download-install/cdrom" "$WINEPREFIX/dosdevices/e:"
"$WINE" reg add 'HKCU\Software\Wine\Drives' /v e: /d cdrom /f
(cd local/runtime/mm3-download-install/cdrom && "$WINE" 'E:\setup.exe')
```

Stop if any preparation command fails. Use the already checksum-verified upstream GE-Proton7-43 runner described in the game README. Do not create prefix subdirectories before Wine initializes them. No physical device or E:: link is used.

In the wizard choose **Normal**, keep the original installation directory, uncheck the bundled **DirectX 6.1**, and finish. Close the SuperStarter frontend the installer opens. Use the paired GE `wineserver -w` to ensure the prefix is stopped before building. The newly created original installed executable is:

`prefix-ge/drive_c/Program Files/IVANOFF Interactive/Skumlesens hævn/mm3run.exe`

A manually copied CAB executable previously showed a trial-expired error; this was not evidence that downloaded media was unusable. The complete original installation supplies the missing state without fabricated registration values or executable patches.

## 3. Build from that fresh installation

```sh
MM3_APPIMAGE_RUNTIME="$PWD/local/runtime/mm3-download-install" \
MM3_APPIMAGE_DIST="$PWD/local/appimage-dist/mm3-download" \
  games/magnus-myggen-skumlesens-haevn/extras/build_appimage.sh
```

The builder checks the original installed EXE hash, refuses a running source prefix, packages the full GE runner, copies original installed state and CD data, and removes only stale drive links in its disposable copy. Source and output overrides leave the older working local-copy AppImage intact.

## 4. Verify no external ISO/install is required

A fresh XDG data directory was used, distinct from the earlier AppImage test. The ISO source directory and external runtime directory were hidden by empty tmpfs mounts using Bubblewrap. Starting the AppImage's FUSE mount inside Bubblewrap was blocked by namespace permissions; this was a test-harness restriction, not a game failure. The exact final AppImage was instead FUSE-mounted outside the sandbox, and its own `AppRun` executed inside it:

```sh
# Terminal 1: leave mounted while the game runs; note the printed mountpoint.
local/appimage-dist/mm3-download/magnus-myggen-skumlesens-haevn-x86_64.AppImage --appimage-mount

# Terminal 2: replace /tmp/.mount_PRINTED with the actual printed path.
bwrap --bind / / --dev-bind /dev /dev \
  --tmpfs "$PWD/local/sources" --tmpfs "$PWD/local/runtime" \
  --setenv XDG_DATA_HOME "$PWD/local/tmp/mm3-download-appimage-state" \
  /tmp/.mount_PRINTED/AppRun
```

This reached the first playable room; the user confirmed expected function. Wine process paths pointed inside the final AppImage's `usr/wine-ge/bin`. Stop the mount holder only after all its Wine processes finish. This test hides sources without deleting or renaming any user's media. For normal use simply execute the `.AppImage`; Bubblewrap is not a runtime dependency.

Saved state is under `${XDG_DATA_HOME:-$HOME/.local/share}/magnus-myggen-skumlesens-haevn/prefix`. Existing default state is shared with the other MM3 AppImage; use a fresh XDG directory when testing provenance. Portability to other distributions and the previously denied full dependency audit remain unverified.
