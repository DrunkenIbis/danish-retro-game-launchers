# Magnus & Myggen: Leg og Lær — Lutris + Wine Wrapper

**Status**: ✅ Arbejdende setup

## Oversigt

Denne mappe indeholder en komplet, fungerende setup til at køre det danske retro-spil **Magnus & Myggen: Leg og Lær** (1997) via Lutris + Wine på Linux.

- **Spilmotor**: Director Player 4.0 (Macromedia Director runtime)
- **Arkitektur**: Win16 game, 32-bit Wine prefix (win98 kompatibilitet)
- **CD-format**: ISO + unpacked CD-ROM mappe
- **Launch-strategi**: Loop-mount ISO eller fallback til udpakket mappe
- **Stabil launch-strategi**: Start som standard fra `C:\MAGNUS\MAGNUS.EXE` med CD'en mappet som `D:`; `D:\MAGNUS.EXE` beholdes som diagnostisk `MM1_MODE=cdgame`

## Struktur

```
.
├── magnus_myggen_leg_og_laer_launch.sh      # Bash wrapper + launch script
├── magnus-myggen-leg-og-laer-lutris.yml     # Lutris integration config
├── Magnus-Myggen-Leg-og-Laer.iso            # CD-ROM image (~170 MB)
├── cdrom/                                    # Unpacked CD files (extracted from ISO)
│   ├── MAGNUS.EXE                          # Main game executable
│   ├── MMSYS.DLL                           # Multimedia system DLL
│   └── [andre resources]
├── wineprefix32/                           # 32-bit Wine prefix (initialized + ready)
│   ├── system.reg / user.reg               # Wine registry
│   ├── drive_c/                            # Virtual C: drive
│   └── dosdevices/                         # Drive mappings (D: -> CD-ROM)
└── README.md                               # This file
```

## Installation (Quick Start)

### Via Lutris GUI
```bash
lutris -i magnus-myggen-leg-og-laer-lutris.yml
# Then launch from Lutris GUI
```

### Via terminal direct
```bash
cd /home/test/lutris_game_scripts_Magnus_Myggen_Leg_og_Laer
./magnus_myggen_leg_og_laer_launch.sh
```

### Environment variables (optional tuning)
```bash
MM1_MODE=game                                   # default stabil installed launch; brug MM1_MODE=cdgame for direkte CD-launch
MM1_NO_VIRTUAL_DESKTOP=1                        # Skip Wine Explorer desktop (experimental)
MM1_CENTER_WINDOW=0                             # Disable X11 window centering
MM1_USE_LOOP_CDROM=1                            # Prefer loop-mount ISO over CD folder
MM1_DESKTOP_SIZE=640x480                        # Wine desktop resolution
MM1_WINVER=win98                                # Windows version compatibility
WINEDEBUG=-all                                  # Suppress Wine debug output (set to +all to enable)

./magnus_myggen_leg_og_laer_launch.sh
```

## AppImage build

Der ligger nu et build-script som pakker spillet, Wine-runtime, prefix og launcher uden Lutris:

```bash
cd /home/test/lutris_game_scripts_Magnus_Myggen_Leg_og_Laer
./build_appimage.sh --appdir-only   # bygger kun AppDir
./build_appimage.sh                 # bygger AppDir + forsøger at lave AppImage
```

Output:
- AppDir: `build/magnus-myggen-leg-og-laer.AppDir`
- AppImage: `dist/magnus-myggen-leg-og-laer-x86_64.AppImage`

Bemærk:
- Scriptet bundler den Wine-version der er installeret på build-maskinen.
- Det gør pakken mere portabel, men ikke 100% garanteret på alle distroer/kernel/glibc-kombinationer.
- Hvis `appimagetool` ikke er installeret, prøver scriptet at hente den automatisk.

## Key Fixes Applied

### 1. Director Memory Error (✅ SOLVED)
**Problem**: "Not enough memory to load 'magnus'" from Director Player 4.0

**Solution**:
- Use installed launch `C:\MAGNUS\MAGNUS.EXE` som standard, mens CD'en stadig er mappet som `D:`
- Keep direct `D:\MAGNUS.EXE` only as a diagnostic fallback (`MM1_MODE=cdgame`) because it can crash later with a Win16 page fault in AppImage/bundled Wine
- Deactivated MMSYS.DLL bytecode hotpatch which was blocking Director's memory allocation
- Uses win98 compatibility mode for stable memory layout

### 2. Loop-mount ISO as CD-ROM
- Wrapper automatically loop-mounts the ISO and maps to `D:` drive
- Falls back to pre-extracted `cdrom/` folder if loop-mount unavailable
- CD checks (CHECKCD function) now pass reliably

### 3. Win16 + Director Runtime Support
- 32-bit Wine prefix configured for Win16 execution
- winevdm.exe handles Win16 VM
- MMSYS.DLL (multimedia) DLL support enabled (but hotpatch disabled)

## Testing & Verification

### ✅ Confirmed Working
- Standalone wrapper launch: spillet starter uden memory-fejl
- Wine process active: `winevdm.exe C:\MAGNUS\MAGNUS.EXE` runs for extended periods
- No error dialogs (wineserver running cleanly)
- Registry keys present: `HKCU\Software\IVANOFF Interactive\MM2`

### Performance
- Base CPU: ~60% when running
- Memory: ~100 MB
- No crashes observed after initial launch phase

## Troubleshooting

### Game won't start
1. Check that ISO is present: `ls -lh Magnus-Myggen-Leg-og-Laer.iso`
2. Verify cdrom folder extracted: `ls cdrom/MAGNUS.EXE`
3. Check Wine prefix initialized: `ls wineprefix32/system.reg`
4. Force wineserver kill: `WINEPREFIX=$(pwd)/wineprefix32 wineserver -k`

### Memory error still appears
- Ensure `MM1_NO_VIRTUAL_DESKTOP=1` is NOT set when virtualdesktop is needed
- Verify no stale wineserver: `pgrep -f 'wineserver.*wineprefix32' && wineserver -k || true`

### Display/window issues
- Set `MM1_CENTER_WINDOW=0` to disable X11 centering helper
- Export `DISPLAY=:0` if running headless

## Notes for Future Maintenance

- **Wine version**: Tested with wow64 Wine (requires wine32 binary available)
- **System requirements**: 32-bit Wine support required (`wine32 wineboot`)
- **Prefix durability**: wineprefix32 is fully initialized and reusable; safe to back up/restore
- **ISO mounting**: Requires `udisksctl` (typically installed) or manual `mount` support

## References

- Wrapper logic: `magnus_myggen_leg_og_laer_launch.sh`
- Lutris documentation: `magnus-myggen-leg-og-laer-lutris.yml`
- Related: Hermes skill `lutris-wine-iso-launchers` (advanced ISO/wrapper patterns)

---

**Last tested**: 2026-06-10  
**Status**: ✅ Ready for use  
**Maintainer**: Test user (Hermes Agent)
