# Global Operations - notes

## 2026-09-14 isolated retail / official patch recheck

- Copied the existing prefix to `local/runtime/global-operations-check/prefix`;
  canonical CD and installed tree were only read. No other game's processes or
  prefixes were stopped.
- Retail Wine 11.0 Staging trace: timeout 20s, exit 124, recurring `\\.\SecDrv`
  lookup failure (`c00000cb`, then `c0000034`), with RpcSs warning. Copied-prefix
  wineserver stopped afterward.
- Retrieved official US 2.0 patch from Patches Scrolls item 44279 using its normal
  download.php/get.php cookie flow. ZIP SHA-256
  `0bf519f3a10abbe587534152d772219f70efc95f4f4b59f4b1f4fae96c75c552`.
- 7z exposes the patch's embedded CAB; unshield extracts Default_File_Group.
  Local unshield requires `LD_LIBRARY_PATH=/home/test/.local/pkg/unshield-rpm/usr/lib64`.
  Only the diagnostic copy received this unchanged patch payload.
- Patch executable test: timeout 18s, exit 124, recurring SecDrv failure as before;
  no menu/mission. Not a successful patch installation or US/EU compatibility
  verdict. The original game/prefix and existing probe scripts are unchanged.
- Original installer CAB lists 1717 entries; the canonical manual startup tree
  does not contain a full install. Treat that as a subsequent setup gap, not the
  cause of the observed SecDrv failures.
- Logs: `local/runtime/global-operations-check/logs/retail-launch.log`,
  `official-patch20-launch.log`, `original-cab-list.txt`.
- No AppImage, performance changes, commit or executable modification.


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

## Original-installer / SecDrv experiment (2026-07-12)

- Added separate `install_secdrv_probe.sh`, `launch_secdrv_probe.sh`, and `secdrv-probe-common.sh`. Their only default mutable root is `local/runtime/global-operations-secdrv-probe/`; they do not reuse `local/runtime/global-operations/`.
- The probe extracts a private CD tree, makes a fresh 32-bit Wine prefix with `win2k`, maps it as `D:`/`GLOBALOPS`, runs the unmodified `D:\Setup\Setup.exe`, and then reports both `HKLM\SYSTEM\CurrentControlSet\Services\SecDrv` and `C:\windows\system32\drivers\SECDRV.SYS` before it can trace the installed game.
- Fresh status before setup: `SecDrv` registry key absent and `SECDRV.SYS` absent from the prefix, while `vol d:` reports `GLOBALOPS` and `dir d:\globalops.exe` succeeds.
- Original Setup.exe was run in the isolated prefix. Wine 11 Staging logged `err:ole:start_rpcss Failed to open RpcSs service`; InstallShield showed only a blank Wine desktop/hung before its wizard and did not install a game, a SecDrv service, or a driver file. The bounded run was stopped and Wine was cleaned up.
- An explicit `wineboot -u` service trace also could not open `RpcSs`. The Fedora Wine packages contain `rpcss.exe`, but the new prefix has no `HKLM\SYSTEM\CurrentControlSet\Services\RpcSs` registration. Therefore this route currently has a Wine service/old InstallShield blocker before it can test the Proton-style SecDrv-install hypothesis.
- A separate `lutris-GE-Proton7-43-x86_64` runner was downloaded from its published release, SHA-512 verified, and used only with `local/runtime/global-operations-secdrv-ge7-probe/`. It identifies as Wine Staging 7.0. This runner did install and start `C:\Program Files\Common Files\InstallShield\Engine\6\Intel 32\IKernel.exe`, which proves the old installer got past the previous `0x80` iKernel installation error.
- The GE-Proton7 experiment still did not reach a usable installer wizard: after more than two minutes the `Global Operations Setup` virtual-desktop window remained an empty blue shell. No installed `globalops.exe`, `SecDrv` service, or `SECDRV.SYS` driver file was created. The run was intentionally stopped and its runner-specific Wine server was cleaned up.
- The probe resolves a sibling `wineserver` for a supplied custom Wine binary, so `GO_SECDRV_WINE_BIN` does not accidentally control its prefix with the host Wine server.
- The scripts force InstallShield's legacy relative temporary engine extraction into the ignored experiment root rather than the tracked `games/global-operations/` directory.

## Next best tests

1. Repeat the isolated original-installer probe with a Wine runner that can start `RpcSs`/InstallShield 6 (for example a verified older Wine/Proton build), still without copying or registering `SECDRV.SYS` manually.
2. If that installer creates both the service and `C:\windows\system32\drivers\SECDRV.SYS`, trace the original installed `globalops.exe` with the authentic `D:` mapping and assess the next SafeDisc/CD-authentication result.
3. Test a lawful DRM-free or official patched executable, keeping `Setup/GAME` DLL/resource files as the working directory.
4. If startup reaches video/D3D, test built-in Wine D3D8 first, then `d3d8to9`, then dgVoodoo2 only if there are rendering/performance/Vsync issues.
5. Verify actual singleplayer gameplay by loading into a mission, not by menu/splash/process evidence.
6. Only after gameplay works, add an AppImage builder via the shared Wine AppImage helper and verify the AppImage to the same in-mission point.
