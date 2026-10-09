# Kaptajn Kaper i Kattegat (Kaper2.zip)

DOS-spillet viser **Version 1 Release 5**, selv om arkivet hedder Kaper2.zip.
Brugeren har bekræftet, at spillet virker som det skal. Ingen yderligere gameplay-test ønsket.

## Installation og start

```sh
./games/kaptajn-kaper-2/install.sh --download --no-launch
./games/kaptajn-kaper-2/launch.sh
```

Alternativt: `install.sh --archive /sti/Kaper2.zip --no-launch` eller `--existing`.
Krav: Python 3.11+, Bash, curl ved download, DOSBox-Staging 0.83 (native eller Flatpak).
Original `GO.BAT` indlæser `GRAFTDA2.COM` og derefter `KAPER.EXE`; ingen separat setup nødvendig.
Fast 1000 cycles, 960×720 vindue, original CGA-grafik og standard CRT-filter.
F1: hjælp. F2: lyd til/fra. Esc: slut.

Private filer ligger i `local/sources/kaptajn-kaper-2` og `local/runtime/kaptajn-kaper-2`.
`REC.DAT` og `TEMP.PIC` bevares ved geninstallation.
Overrides: `RETRO_GAME_SOURCE_DIR`, `RETRO_GAME_RUNTIME_DIR` (basismapper),
`KAPER_SOURCE_DIR`, `KAPER_RUNTIME_DIR`, `KAPER_ARCHIVE`, `KAPER_CPU_CYCLES`,
`KAPER_DOSBOX_BIN`, `KAPER_DRY_RUN=1`.

## Privat AppImage

```sh
./games/kaptajn-kaper-2/extras/build_appimage.sh
./games/kaptajn-kaper-2/extras/dist/kaptajn-kaper-2-x86_64.AppImage
```

Byggeren bruger repoets eksisterende checksum-fastlåste DOSBox- og AppImage-værktøjer.
Spilfiler udtrækkes fra originalarkivet i en frisk mappe; brugerens aktuelle spiltilstand kopieres ikke.
Spillet og DOSBox 0.83 er indbygget. Wine, Flatpak, system-DOSBox og Python kræves ikke ved spilstart.
Værten skal have x86-64 Linux, Bash/coreutils/flock, kompatibel glibc/libstdc++, X11/XWayland,
grafik- og lyddrivere samt normalt FUSE. Alternativt anvendes `--appimage-extract-and-run`.
Brugerdata ligger i `${XDG_DATA_HOME:-$HOME/.local/share}/kaptajn-kaper-2` og overskrives ikke ved genstart.
Pakken er privat og indeholder spilfiler; må ikke lægges i Git.

## Verifikation

- Download/checksum og installation udført.
- Fire isolerede opskriftstests består (udtræk, databevarelse, checksum, manglende fil og symlink-kontrol).
- Kattegat-kort og F1-hjælp visuelt set gennem den almindelige launcher.
- Brugeren bekræfter spillet fungerer; særskilt agent-lytteprøve ikke udført.
- AppImage: se `notes.md` for pakkekontrol; gameplay-bekræftelsen gælder kilde-launcheren, ikke automatisk pakken.
