# Portable packaging review fixes (source only)

No AppImage was built and no game or guest was launched for these changes. The
Mint TCG `GS:0000` crash remains unresolved; these fixes are not a Mint pass.

## Boundaries

- The builder copies the seed with `cp -a` (no dereferencing), then calls
  `portable_overboard.sanitize_prefix()` on **the staged copy only**. Known Wine
  user-folder symlinks become empty directories. Non-C `dosdevices` symlinks are
  removed, then every remaining prefix symlink must resolve inside that prefix.
  Unknown escaping links and link loops fail the build; personal targets are not
  read or copied. Existing real user-folder directories are not deleted.
- `portable-display` selects `display/share/gamescope/scripts` using
  `GAMESCOPE_SCRIPT_PATH` and refuses an empty/missing Lua-script tree.
- The wrapper saves original `XDG_DATA_DIRS` before altering it, preserving that
  value across Gamescope -> Python re-entry. `display_runner.wine_environment()`
  removes compositor Vulkan/EGL/driver discovery settings only for Wine and its
  wineserver, and restores those original data paths (standard system share
  paths when unset). Display children keep the compositor environment.
- **The Wine payload supports the existing 32-bit X11/GLX path, not Vulkan.**
  `winevulkan` is disabled for the portable launch; no i386 Vulkan ICDs were
  added. Gamescope still uses its private ELF64 Vulkan runtime. Wine's private
  wrapper selects its i386 GL drivers. The confirmed Wayland Gamescope backend,
  fit scaling, Xephyr glamor and 1024x768x16 starting mode are unchanged.
- Top-level and outer display launchers use `Popen` supervision. A parent-only
  SIGTERM/SIGINT is forwarded once, and the prefix lock stays held until cleanup
  returns. The dedicated outer Linux supervisor uses `PR_SET_CHILD_SUBREAPER`
  and a separate compositor session. It enumerates only its descendant tree
  through `/proc` and forwards signals with pidfds, including clients that start
  their own sessions; it waits for adopted descendants even if Gamescope exits
  first. This path requires Linux pidfd support. Inner cleanup ignores repeated termination,
  waits for matching wineserver shutdown without a timeout, then reaps Xephyr.
  A stuck cleanup intentionally retains the lock/mount rather than falsely
  reporting completion. SIGKILL cannot be made graceful by Python handlers.
- Display bundling now rejects a nonzero `ldd` result as well as missing-library
  output, including stderr in diagnostics.

## Regression coverage

`test_portable_review.py` tests synthetic prefix links, script lookup and empty
script rejection, Python re-entry environment preservation, Wine-only environment
sanitization and real `ldd` failure handling. `test_portable_signals.py` uses real
subprocesses but synthetic Wine/display executables; it exercises parent-only and
repeated signals, blocked second launches during cleanup, lock release afterward,
child reaping, early compositor exit, and production inner cleanup with delayed
synthetic wineserver exit. No gameplay is involved.

Run focused tests from this directory:

```sh
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest \
  test_portable_review test_portable_signals test_display_runner -v
bash -n portable-display build_portable_appimage.sh
```

The full existing suite requires `python-xlib` and `six`. Neither default Python
nor `/usr/bin/python3` had Xlib available directly in this environment. The full
suite was run using the already staged vendor directory, read-only, with bytecode
writes disabled (no dependency installation):

```sh
PYTHONDONTWRITEBYTECODE=1 TMPDIR="$PWD" \
PYTHONPATH=/home/test/danish-retro-game-launchers/local/appimage-build/overboard-portable/Overboard.AppDir/game/vendor \
/usr/bin/python3 -m unittest discover -p 'test_*.py' -v
```

These source tests do not establish final AppImage mount lifetime, bundled Python
`prctl` availability, real Gamescope termination behavior, graphics, audio or
cross-machine compatibility. Those remain artifact-level verification gates.
