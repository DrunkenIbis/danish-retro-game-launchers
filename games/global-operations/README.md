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
