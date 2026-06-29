# Global Operations - notes

## Media inspection

- Source URL: `https://archive.org/download/GlobalOperationsEuropeEnFrDe/Global%20Operations%20%28Europe%29%20%28En%2CFr%2CDe%29.zip`
- ZIP contents:
  - `Global Operations (Europe) (En,Fr,De).bin` (601,681,584 bytes)
  - `Global Operations (Europe) (En,Fr,De).cue`
- CUE contents:
  - `TRACK 01 MODE1/2352`
- Conversion used by `install.sh`: for each 2352-byte sector, copy bytes 16..2063 to the ISO.
- Converted ISO size observed: 523,913,216 bytes.
- Volume label observed through Wine after extraction/mapping: `GLOBALOPS`.

## Disc layout and real launch path

`AUTORUN.INF`:

```ini
[autorun]
open=AUTORUN.EXE
Icon=uzi.ico
Name=Global Operations
```

Important files found on the converted ISO:

```text
globalops.exe
secdrv.sys
AutoRun.exe
Setup/Setup.exe
Setup/Setup.ini
Setup/GAME/Engine.REZ
Setup/GAME/mss32.dll
Setup/GAME/Smackw32.dll
Setup/GAME/goserver.exe
ReadMe/readme_eng.txt
```

`file` reports:

```text
globalops.exe: PE32 executable for MS Windows 4.00 (GUI), Intel i386
Setup/Setup.exe: PE32 executable for MS Windows 4.00 (GUI), Intel i386
Setup/GAME/goserver.exe: PE32 executable for MS Windows 4.00 (GUI), Intel i386
secdrv.sys: PE32 executable for MS Windows 4.00 (native), Intel i386
```

`winedump`/`objdump` showed that `globalops.exe` imports `d3d8.dll`, `dinput8.dll`, `ddraw.dll`, `mss32.dll`, `winmm.dll`, `wsock32.dll`, and common Win32 DLLs.

The CD root `globalops.exe` is the actual game executable, but it does not find `mss32.dll` when launched from the CD root. The wrapper therefore creates a runtime copy from `Setup/GAME/` plus the disc-root `globalops.exe` and runs from that directory.

## Wine tests performed

Environment:

- Host has `wine32`, `wine`, `7z`, `cabextract`, `ffprobe`.
- Dedicated Wine prefix: `local/runtime/global-operations/wineprefix32`.
- Wine drive `D:` mapped to `local/runtime/global-operations/cdrom` and tagged as `cdrom` in `HKCU\Software\Wine\Drives`.
- `wine32 cmd /c 'vol d: && dir d:\globalops.exe'` verified `GLOBALOPS` label and the executable path.

Test 1: direct CD-root launch from CD root

- Command shape: `wine32 explorer /desktop=GlobalOperations,1024x768 D:\globalops.exe`
- Result: exits quickly with `err:module:loader_init Importing dlls for L"D:\\globalops.exe" failed, status c0000135`.
- Cause: missing `mss32.dll` in that working directory/search path.

Test 2: `D:\globalops.exe` with `Setup/GAME` as working directory

- Result: gets past missing `mss32.dll` and reaches SafeDisc/SecDrv behavior.
- Trace repeatedly shows:

```text
CreateFileW "\\.\SecDrv" GENERIC_READ GENERIC_WRITE
NtCreateFile name="\\??\SecDrv" -> c00000cb / c0000034
```

- The disc contains `secdrv.sys`, matching the SafeDisc 2 warning for this retail version.
- No game menu or playable mission was verified.

## Current status

`blocked-safedisc-secdrv-under-wine`.

This is not considered working. The wrapper is useful because it reproducibly prepares media, prefix, CD mapping, and the correct executable working directory, then documents the exact DRM boundary.

## Patches / wrappers / multiplayer

- SafeDisc: present. The retail executable tries `\\.\SecDrv`; Wine does not provide that kernel driver path. Additional PCGamingWiki notes say this SafeDisc version does not work on Windows 10/11 and is disabled by default on Windows Vista/7/8/8.1 when KB3086255 is installed, so the blocker is expected on modern Windows too.
- DRM-free executable: not verified. Do not add no-CD patches or byte patches to this repo. If the user provides a lawful DRM-free executable or official re-release, retest with the same runtime tree and document the source.
- Official patch: disc includes `ArcadeInstallGLOBALOPS108g.exe`, but this session did not verify whether it updates the retail executable or removes/retains SafeDisc. Treat it as a next-step diagnostic, not a solution.
- dgVoodoo2 / d3d8to9: relevant only after startup gets past SafeDisc. PCGamingWiki recommends these for Direct3D 8 performance/Vsync issues on modern Windows. Additional notes say System Informer sees `d3d8.dll` and DebugView++/dgVoodoo2 traces identify `Direct3DDevice8`. They were not integrated here because no D3D scene was reached.
- Widescreen/config: PCGamingWiki says `<path-to-game>\Global\profile\<user-id>.cfg` supports manual `screenwidth`/`screenheight`; `1920x1080` is reported working, but non-4:3 is stretched without an FOV fix and some menu resolutions can break. Not tested because no profile/config was generated before SafeDisc blocked startup.
- Audio/EAX: PCGamingWiki notes EAX 2.0 listener/buffer property usage traced with DSOAL. DSOAL/EAX wrappers were not tested because gameplay/audio initialization was not reached.
- Native Windows write redirection: on Vista and later, writes under `%PROGRAMFILES%`, `%PROGRAMDATA%`, or `%WINDIR%` may go to `%LOCALAPPDATA%\VirtualStore` without elevation. Keep this in mind when comparing native Windows traces or save/config locations; the repo launcher avoids this by using writable ignored runtime paths.
- Winetricks/components: no required winetricks component was proven before the SafeDisc blocker. Bundled Miles/Smacker DLLs must be in the executable directory.
- Multiplayer: GameSpy is shut down; PCGamingWiki says 333networks is the replacement path. No multiplayer verification was possible.

## Next best tests

1. Test a lawful DRM-free or official patched executable, keeping `Setup/GAME` DLL/resource files as the working directory.
2. If startup reaches video/D3D, test built-in Wine D3D8 first, then `d3d8to9`, then dgVoodoo2 only if there are rendering/performance/Vsync issues.
3. Verify actual singleplayer gameplay by loading into a mission, not by menu/splash/process evidence.
4. Only after gameplay works, add an AppImage builder via the shared Wine AppImage helper and verify the AppImage to the same in-mission point.
