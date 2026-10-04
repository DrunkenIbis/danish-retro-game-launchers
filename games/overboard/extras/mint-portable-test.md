# Private kernel-free portable Overboard: Mint test

## Status

Experimental; **Mint gameplay is not verified**. This is a packaging recipe from a locally prepared seed, not yet a complete original-media-to-runtime build. Do not publish the private game-containing artifact.

Latest tested artifact:
`local/appimage-dist/overboard-portable-v4/Overboard-KernelFree-Portable-x86_64.AppImage`

SHA-256 (host and guest matched):
`87927abf688192dfb76dd8199b9d211dd3a4ff6a4f16a33624ee63f0b26c39d8`

## Verified

- Built the artifact; the older reference and earlier portable builds were retained.
- 20 Overboard automated tests pass after the v4 changes.
- Tested as ordinary user `tester` in the installed Mint 22.3 Xfce VM, using QEMU software emulation (TCG), no network.
- Guest package inventories before/after match exactly. No guest dependency packages were installed.
- `/lib/ld-linux.so.2` remains absent in the guest.
- Runtime provenance records the private i386 loader and mapped WinMM emulator in the exact test prefix. This is runtime evidence, not gameplay evidence.
- Both nested-server readiness and the size-helper readiness now have a configurable 120-second default via `OVERBOARD_XSERVER_TIMEOUT`; short deadlines failed under TCG.
- The bundled Python wrapper no longer exports display-specific driver settings itself. Display wrappers still configure their own private graphics runtime. Wayland child-environment isolation needs further auditing.
- `OVERBOARD_WINEDEBUG` permits diagnostics without changing the default `-all`.

## Remaining failure

The v4 run got beyond size-helper readiness and into Wine/Direct3D initialization. The guest screenshot showed a black Xephyr window, not a playable scene. The log eventually reported a Wine page fault:

```
MESA: error: ZINK: vkCreateInstance failed (VK_ERROR_INCOMPATIBLE_DRIVER)
glx: failed to create drisw screen
... GL_RENDERER "llvmpipe (LLVM 17.0.6, 256 bits)" ...
... context_choose_pixel_format Trying to locate a compatible pixel format because an exact match failed.
wine: Unhandled page fault on read access to 0000000C at address E8B2F469 (thread 010c), starting debugger...
```

The log also contains Wine service timeouts. These messages establish an unsuccessful run, not the precise cause of the crash. It is not yet established whether the failing software-rendered graphics path reflects a packaging omission, a runtime compatibility defect or the VM graphics setup. Do not claim that every dependency is present merely because `--check` passes.

Mint Xfce uses the direct X11 fallback, without Gamescope's Wayland aspect-preserving maximized scaling. This test cannot validate that feature. Earlier user-confirmed host source-launcher gameplay does not validate the new packaged artifact.

## Follow-up isolation

The fault address was mapped from the saved guest process maps to the bundled
32-bit libc at file offset `0x90469`. Disassembly identifies the faulting
instruction as `mov %gs:0xc,%eax` inside `__pthread_mutex_lock`, not a Mesa
instruction. The calling path still requires investigation.

The unchanged v4 AppImage was then run on the Fedora host with
`LIBGL_ALWAYS_SOFTWARE=1`, first through Gamescope and then with
`OVERBOARD_DISPLAY=direct`. The direct run reached the menu and the first level.
A held Right key visibly rotated the player's ship (before/after captures
`portable-v4-software-direct-play.png` and `portable-v4-software-direct-steer.png`
under `local/runtime/overboard-kernel-free-probe`). Logs confirm llvmpipe LLVM 17.
This establishes interactive rendering/steering on the host in that mode, not
Mint success, audio verification or Wayland output/tearing validation.

A separate VM-only hypothesis test uses `MINT_TEST_CPU=max,fsgsbase=off` in the
VM launcher; default CPU configuration remains `max`. No AppImage bytes or guest
packages change for this comparison. FSGSBASE was confirmed absent in the guest,
but the game still crashed at `F3151469` with `GS:0000` and the instruction
`mov %gs:0xc,%eax`. This probe did not fix the crash. The possible QEMU exception-
type mismatch is documented in `../PORTABLE-FINDINGS.md`, not yet verified.

## Evidence

Local evidence directory (not for committing):
`/home/test/VMs/mint-battlefield-test/results/overboard-portable/`

- `launch.log`: v4 Wine/display log.
- `provenance.json`: exact-prefix process cmdlines, executables and mapped private libraries.
- `packages-before.txt`, `packages-after.txt`: unchanged guest package inventory.
- `v4-later.png`: black guest game window before the final fault was read.

Still required: diagnose the graphics crash, verify deliberate interactive gameplay and audio on the final artifact, then repeat with existing state. Hardware/Wayland artifact verification and a clean reproducible seed recipe are separate unfinished gates.
