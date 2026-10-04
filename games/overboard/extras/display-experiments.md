# Kernel-free display experiments

Host-only test launcher: `bash games/overboard/extras/launch_kernel_free_test.sh`.
Requires the existing local probe prefix, Wine runner, Xephyr, Gamescope, uv,
and an accessible local X11 display. This is not yet a portable AppImage.

- Default: software Xephyr, 16-bit root, Gamescope aspect-preserving `fit`.
- `OVERBOARD_COPY_FRAMES=1`: Xephyr-only `XEPHYR_NO_SHM=1`.
  Verified in the running process, but horizontal temporal discontinuities
  remained visible in `copy-frames-sequence.png`. Not promoted to default.
- `OVERBOARD_GLAMOR=1 OVERBOARD_COPY_FRAMES=0`: Xephyr `-glamor`.
  Verified actual X11 root depth 16 and loaded GLX Mesa libraries. Maximized
  intro sequence and menu were captured without the obvious horizontal
  discontinuities seen in the copy-mode sample. This is promising, not proof
  of flicker-free gameplay; manual movement/play validation remains required.

Evidence lives under `local/runtime/overboard-kernel-free-probe/`:
`scaled-copy-frames.log`, `copy-frames-sequence.png`, `scaled-glamor.log`,
`glamor-sequence.png`, `glamor-menu.png`.

## Wayland output probe

```bash
OVERBOARD_GAMESCOPE_BACKEND=wayland OVERBOARD_GLAMOR=1 OVERBOARD_COPY_FRAMES=0 bash games/overboard/extras/launch_kernel_free_test.sh
```

This changes Gamescope's outer backend, not Wine's X11 backend or Xephyr's
16-bit depth. Log `glamor-wayland-writable-tmp.log` confirms Wayland backend
initialization and refresh selection of 119.974 Hz. Inner game content was
captured, but the desktop capture tool failed on the native Wayland output;
maximized scaling and absence of tearing initially required user validation.
The user subsequently confirmed this Wayland/glamor/copy-off combination worked
very well. That confirms the source-launcher comparison, not a later AppImage.
The first start failed because GTK/glycin could not write under inherited
TMPDIR in the read-only sandbox; the launcher now binds that scratch directory
writable. No KDE/NVIDIA workarounds or GPU-selection overrides were added.

## User-validated comparison

With `OVERBOARD_GLAMOR=1 OVERBOARD_COPY_FRAMES=0`, launch the same helper
without Gamescope using:

```bash
OVERBOARD_GLAMOR=1 OVERBOARD_COPY_FRAMES=0 bash games/overboard/extras/launch_kernel_free_test.sh --inner
```

The user reported no problems in this direct-Xephyr test, after reporting
horizontal tearing in both gameplay and intro with Gamescope. This implicates
the additional Gamescope presentation path or its interaction with Xephyr;
it does not identify the precise synchronization defect. Preserve direct
Xephyr as the working comparison baseline. Aspect-preserving maximized
upscaling is NOT supplied by this direct mode and remains unresolved.

Keep only one probe using this prefix running. Exiting it also shuts down
that prefix's wineserver. Never kill unrelated Wine prefixes.

Do not reintroduce Xephyr `-resizeable`: its internal resolution is controlled
from Wine desktop geometry, while Gamescope handles outer window scaling.
Mode changes in logs alone do not prove a resize feedback loop: intro clips,
menus and gameplay can legitimately switch modes. Correlate with timestamps
and captured visual state before attributing flicker to mode switching.

For A/B experiments, change one rendering variable at a time and keep the
software path available. A sampled still/sequence cannot establish absence of
all flicker between frames or during gameplay.
