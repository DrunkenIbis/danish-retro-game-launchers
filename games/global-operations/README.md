# Global Operations

Status: installer/launcher verified to the SafeDisc boundary; gameplay is blocked by retail SafeDisc/SecDrv under Wine  
Runner: Wine (`wine32` preferred)  
Source: ZIP containing a single-track `MODE1/2352` BIN/CUE Windows CD-ROM image

This directory contains only the compatibility recipe. It does not contain the game ZIP, BIN/CUE, converted ISO, extracted CD data, Wine prefix, screenshots, logs, or build output.

## Quick start

From this directory:

```sh
./install.sh --download --no-launch
./launch.sh
```

Current expected result on this Fedora/Wine machine is not gameplay. The protected retail executable reaches the SafeDisc/SecDrv check and does not enter the game.

## Private files

Default private paths:

```text
local/sources/global-operations/Global Operations (Europe) (En,Fr,De).zip
local/sources/global-operations/Global Operations (Europe) (En,Fr,De).bin
local/sources/global-operations/Global Operations (Europe) (En,Fr,De).cue
local/sources/global-operations/Global Operations (Europe) (En,Fr,De).iso
local/runtime/global-operations/cdrom/
local/runtime/global-operations/installed/GlobalOps/
local/runtime/global-operations/wineprefix32/
```

Override examples:

```sh
GO_ISO=/path/to/GlobalOps.iso ./launch.sh
RETRO_GAME_SOURCE_DIR=~/retro-game-files RETRO_GAME_RUNTIME_DIR=~/retro-game-runtime ./launch.sh
GO_WINE_BIN=/path/to/wine32 ./launch.sh
```

## Installer modes

```sh
./install.sh                 # interactive
./install.sh --download      # download ZIP, convert BIN/CUE data track, validate, then launch
./install.sh --download --no-launch
./install.sh --existing --no-launch
./install.sh --iso /path/to/GlobalOps.iso --existing --no-launch
```

The Archive.org reference ZIP contains:

```text
Global Operations (Europe) (En,Fr,De).bin
Global Operations (Europe) (En,Fr,De).cue
```

The CUE is a single data track:

```text
TRACK 01 MODE1/2352
```

`install.sh` extracts the BIN/CUE and creates `Global Operations (Europe) (En,Fr,De).iso` by copying bytes `16..2063` from each 2352-byte sector. The converted ISO validates with these launcher-critical paths:

```text
AUTORUN.INF
AutoRun.exe
globalops.exe
secdrv.sys
Setup/Setup.exe
Setup/Setup.ini
Setup/GAME/Engine.REZ
Setup/GAME/mss32.dll
Setup/GAME/Smackw32.dll
Setup/GAME/goserver.exe
ReadMe/readme_eng.txt
```

## Launcher modes

```sh
./launch.sh                  # default: GO_MODE=game
GO_MODE=prepare ./launch.sh  # extract CD, create manual runtime copy, initialize prefix
GO_MODE=game ./launch.sh     # run manual runtime copy: Setup/GAME + globalops.exe
GO_MODE=cdgame ./launch.sh   # run D:\globalops.exe with the manual runtime CWD
GO_MODE=autorun ./launch.sh  # run D:\AutoRun.exe
GO_MODE=setup ./launch.sh    # run D:\Setup\Setup.exe
GO_MODE=kill ./launch.sh
```

The wrapper maps the extracted CD as Wine drive `D:` with label `GLOBALOPS`, initializes a dedicated 32-bit prefix, and creates a manual runtime install tree from `Setup/GAME/` plus the disc-root `globalops.exe`. That manual tree is not a no-CD modification; it only puts `mss32.dll`, `Engine.REZ`, `Smackw32.dll`, and the game EXE in one working directory so the real blocker can be isolated.

## Verified blocker

Verified on this machine:

- `AUTORUN.INF` points to `AutoRun.exe`.
- The real game executable on the disc is `globalops.exe`.
- Launching `D:\globalops.exe` from the CD root fails earlier with `status c0000135` because `mss32.dll` is not in the CD-root DLL search path.
- Launching with `Setup/GAME` as the working directory or from the manual runtime copy gets past the missing-DLL issue and reaches the retail protection path.
- Wine trace shows repeated attempts to open `\\.\SecDrv`, and the disc contains `secdrv.sys`.
- That is SafeDisc/SecDrv, not a plain Wine `D:` mapping problem. `cmd /c vol d:` reports `GLOBALOPS`, and `dir d:\globalops.exe` sees the executable.

Representative trace signal:

```text
CreateFileW "\\.\SecDrv" GENERIC_READ GENERIC_WRITE
NtCreateFile name="\\??\SecDrv" -> c00000cb / c0000034
```

Because the SafeDisc driver path is unavailable under Wine, gameplay was not verified. Do not mark this recipe as working until a lawful DRM-free executable/official re-release/compatible build is supplied and an actual mission loads past menus/splash screens.

## Isolated original-installer SecDrv experiment

The normal `launch.sh` runtime is intentionally kept separate from this diagnostic path. These scripts use only `local/runtime/global-operations-secdrv-probe/`:

```sh
./install_secdrv_probe.sh --prepare
./install_secdrv_probe.sh           # original D:\Setup\Setup.exe
./install_secdrv_probe.sh --status  # checks SecDrv service and driver file
./launch_secdrv_probe.sh            # installed EXE plus SafeDisc/SecDrv trace
```

The probe creates a fresh 32-bit Wine prefix in `win2k` mode, maps the original extracted CD as `D:`, starts the unmodified InstallShield installer, then checks both `HKLM\SYSTEM\CurrentControlSet\Services\SecDrv` and `C:\windows\system32\drivers\SECDRV.SYS`. It does not copy or register `SECDRV.SYS` itself.

Current result on the system Wine 11 Staging host: the original InstallShield 6 installer does not reach its visible wizard. Its trace ends at `err:ole:start_rpcss Failed to open RpcSs service`; neither the SecDrv service nor the driver file is created. This is an installer/Wine-service blocker before the existing SafeDisc test, not evidence that SecDrv is installed or working.

A second isolated test used the downloaded `lutris-GE-Proton7-43-x86_64` runner (Wine Staging 7.0). It successfully installed and started `IKernel.exe`, so it cleared the prior `0x80` engine-install error. But after more than two minutes its `Global Operations Setup` window remained an empty blue shell: no wizard, installed `globalops.exe`, SecDrv service, or driver file was created. The original `launch.sh` route remains the canonical recipe and remains blocked at SafeDisc.

## Recheck 2026-09-14

The current retail path was retested under system Wine 11.0 Staging in a copied
prefix, without changing the canonical installation. A 20-second bounded trace
again repeatedly failed to open `\\.\SecDrv` (`c00000cb`/`c0000034`). No
playable game was reached. The prefix's RpcSs warning is also still present.

The official **US 2.0 patch** was obtained from The Patches Scrolls:
https://www.patches-scrolls.de/patch/1849/7/44279/download

`glopsus2_0.zip`, 11,881,330 bytes, SHA-256:
`0bf519f3a10abbe587534152d772219f70efc95f4f4b59f4b1f4fae96c75c552`

Its unmodified application payload was extracted and overlaid only onto a
separate diagnostic tree. An 18-second trace of its executable still produced
repeated SecDrv failures. This is NOT a verified complete patch installation,
proof of US/EU patch compatibility, or a DRM-free update. The normal game files
remain unchanged. Both tests were explicitly stopped and their copied-prefix
Wine server cleaned up.

Private evidence: `local/runtime/global-operations-check/logs/`.
Patch archive/extraction: `local/cache/global-operations/`.
The manual `Setup/GAME + globalops.exe` tree is only a startup diagnostic tree,
not a complete installed game: the original InstallShield CAB lists 1717 entries,
including additional game data. After a compatible startup path is available,
the full installation must also be established before claiming gameplay.

No graphics/audio tuning or AppImage was added: neither fixes this pre-game
protection dependency. Existing original-installer experiments are preserved.

## Patches and compatibility fixes investigated

- SafeDisc 2 / disc check: present and currently blocks Wine startup. PCGamingWiki notes this SafeDisc version does not work on Windows 10/11 and is disabled by default on Windows Vista/7/8/8.1 when Microsoft KB3086255 is installed; Wine shows the same class of blocker as repeated `\\.\SecDrv` probes.
- Official patches: the CD contains `ArcadeInstallGLOBALOPS108g.exe`, but no DRM-free executable was verified in this session. PCGamingWiki notes a complete patch list exists; installing a patch may still leave retail SafeDisc in place and must be tested with a lawful executable.
- Direct3D 8: the executable imports `d3d8.dll`; PCGamingWiki/System Informer/DebugView++ notes point to Direct3D 8/`Direct3DDevice8`, and PCGamingWiki recommends dgVoodoo2 or crosire's `d3d8to9` for poor performance/Vsync on Windows 8+. Those wrappers were not integrated because this run never gets past SafeDisc; D3D wrappers are a second-stage compatibility fix, not a DRM fix.
- Widescreen/config: PCGamingWiki reports manual widescreen values in `<path-to-game>\Global\profile\<user-id>.cfg`; `1920x1080` has been verified by a PCGamingWiki user, but non-4:3 resolutions are stretched unless an FOV fix is used and some resolutions may break menus. This recipe has not reached a profile/config generation point.
- Audio/EAX: PCGamingWiki notes EAX 2.0 behavior traced through DSOAL-style logs. No DSOAL/EAX wrapper was integrated because startup is blocked before audio/gameplay validation.
- UAC/VirtualStore: on Windows Vista and later, non-elevated writes under `%PROGRAMFILES%`, `%PROGRAMDATA%`, or `%WINDIR%` can be redirected to `%LOCALAPPDATA%\VirtualStore`. The Wine recipe uses ignored writable runtime paths instead of installing below real Program Files, but this is relevant when comparing native Windows traces.
- Extra DLLs/components: the game needs its bundled `mss32.dll` in the executable working directory. No winetricks component was proven necessary before the SafeDisc blocker.
- Multiplayer: original GameSpy service is shut down. PCGamingWiki says online play uses 333networks; this recipe has not verified multiplayer. Treat singleplayer as the first target once the DRM blocker is removed.

## AppImage status

No AppImage was created. The base Wine recipe is blocked before gameplay by SafeDisc/SecDrv, so packaging the same protected executable would only bundle a known-broken launch path. Next best AppImage test: first verify a lawful DRM-free or otherwise Wine-compatible executable through `launch.sh`, then add the usual Wine AppImage helper integration and smoke-test the AppImage to the same in-mission gameplay point.

## Metadata

- Developer: Barking Dog Studios
- Publisher: Crave Entertainment / Electronic Arts
- Year: 2002
- Languages: English, French, German
- Platform: Microsoft Windows
- Engine: LithTech Talon
- Genre: Tactical first-person shooter, singleplayer and multiplayer
