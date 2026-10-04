# Kernel-free portable Overboard: consolidated findings

## Scope and status

Private owner-supplied game bundle; Git contains recipes/tests/documentation only.
Original media, EXE, prefixes, logs, captures and AppImages remain outside Git.
The kernel-free source launcher is user-confirmed playable. The v4 AppImage is
visually verified in a host software-rendered direct-X11 run, including deliberate
ship steering. Mint/TCG crashes; full cross-machine portability is not certified.
Do not confuse a payload `--check` with gameplay or complete dependency coverage.

## CD emulation

Original `Ob.exe` SHA-256:
`eada7fd94364f42ea10a2317f16c9df313d41e15ea9cb37303931f831a1f3717`.
Keep this executable unmodified. Data-only ISO and ordinary Wine CD mappings did
not reproduce the original mixed-mode disc. Upstream ogg-winmm alone also failed.
The working compatibility path provides original-disc TOC positions and Ogg audio
through a native WinMM proxy, without CDEmu/VHBA or an optical device.

Upstream ogg-winmm revision: `11c13ecf727fc0b00b46e04acbf503a60e7df1db`.
`ogg_tracks.py` computes track positions including the 150-frame lead-in,
data-track lengths, SILENCE and START pregaps. Regression fixture: `[150,1050,1427]`.
`prepare_ogg_toc_probe.py` generates the source/INI adaptation. Upstream INI is
`resource/winmm.ini`. Seed game directory contains `winmm.dll`, `winmm.ini` and
`Music/Track02.ogg` onwards. Private-/dev host testing and saved provenance support
the no-optical-device result. The full media/compiler-to-seed pipeline is not yet
a single reproducible builder; the portable builder consumes this prepared seed.

## Display decisions and rejected experiments

- Preserve Xephyr's actual 16-bit root; the original intro depends on this path.
- A helper follows Wine desktop size; do not enable Xephyr `-resizeable` as a
  competing geometry controller. Intro/menu/gameplay can legitimately change size.
- Gamescope uses `-S fit`, never stretched scaling.
- Software Xephyr and SHM-copy probing did not eliminate moving-image tearing.
- Glamor alone with Gamescope's SDL backend was insufficient. Menus looking clean
  did not establish flicker-free intro/gameplay.
- Direct Xephyr + glamor was user-confirmed free of the reported tearing, but does
  not provide aspect-preserving maximized scaling.
- Gamescope **Wayland** + Xephyr glamor + copy mode off was user-confirmed good.
  Preserve that complete combination for the normal Wayland launcher.
- Bubblewrap probes need correct local X socket parsing (`:0.0` -> `X0`) and a
  writable inherited TMPDIR. Do not truncate the full `.X11-unix` pathname at `.`.

Full experiments: [display-experiments.md](extras/display-experiments.md).

## Runtime packaging

The portable variant bundles Wine-GE 7-43, private i386/amd64 Linux loaders and
libraries, Python 3.14, Python-Xlib/six, Xephyr, Xwayland, xkbcomp and Gamescope.
Ubuntu Wine libraries and Fedora display libraries use separate explicit-loader
search paths, not a global foreign LD_LIBRARY_PATH. Relative Wine NLS links are
required because direct loader invocation changes executable-relative lookup.
Private Python needs `PYTHONHOME`, `PYTHONPLATLIBDIR=lib`, and an explicit
`OVERBOARD_PYTHON` re-exec path; `sys.executable` can otherwise name the loader.
Only ELF64 display drivers belong in the 64-bit display runtime.

This is a Linux x86_64 desktop package, not a guest OS or a universal ABI guarantee.
A working display session, kernel/graphics compatibility and host shell remain
requirements. X11-only desktops select the direct mode, without Wayland scaling.
The host-derived display dependency collection is recorded but not version-pinned
as a complete rebuild input. Driver/plugin/resource loading needs runtime tests.

## Mint results and GS investigation

See [mint-portable-test.md](extras/mint-portable-test.md) for artifact hash and
precise evidence. Guest packages were unchanged and system i386 loader absent;
private Wine loader and WinMM were mapped. TCG required longer startup deadlines.
Guest crashes at a libc GS-relative TLS read, not at a demonstrated missing-library
loader error. Disabling FSGSBASE did not fix it: the repeat reports `GS:0000`,
`mov %gs:0xc,%eax`, and another page fault. Host direct-X11 llvmpipe rendering and
actual steering succeeded with the same v4 bytes.

### External research (hypothesis, not a verified fix)

Wine 7.0 `signal_i386.c` contains `check_invalid_gs`, restoring the native GS for
eligible system-library faults. It is called from segment-not-present/general-
protection handling, not from the separate page-fault branch:
https://raw.githubusercontent.com/wine-mirror/wine/wine-7.0/dlls/ntdll/unix/signal_i386.c

A later discussion references Wine MR 7064 (64-bit GS fault handling) and reports
success for Alice: Madness Returns and BloodRayne under new-style WoW64. That is
not our classic 32-bit Wine configuration and is not a directly verified fix:
https://www.phoronix.com/forums/forum/software/desktop-linux/1516570-wine-10-0-rc4-released-with-another-13-bugs-fixed

A separate OSDev report describes segment-check differences between QEMU and
physical hardware/VirtualBox; it is a bootloader case, not an Overboard report:
https://forum.osdev.org/viewtopic.php?t=56103

Working hypothesis: TCG may deliver a page fault where physical hardware would
trigger GS repair through a different exception. Neither that mechanism nor its
applicability to the exact Wine-GE build is proven. Next discriminating experiment:
a small 32-bit invalid-GS exception probe on host and guest, with trap numbers and
registers recorded. No game EXE patch or speculative package installation follows
from these sources. No exact public Overboard/Mint/TCG crash match was found.

## Release acceptance still separate

Keep host gameplay, host Wayland motion/scaling, audio, fresh/reused state, and
Mint compatibility as separate gates. A release artifact may be delivered with
explicit limitations; never relabel the unresolved Mint test as a pass. Keep the
legacy reference and v4 evidence intact; record the final file digest and source
commit in a separate release record. No push or game-data redistribution.
