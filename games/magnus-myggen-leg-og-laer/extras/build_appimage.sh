#!/usr/bin/env bash
set -Eeuo pipefail

# Build an AppDir/AppImage that bundles the game files + Wine runtime.
# NOTE: "all Linux distros" can never be guaranteed 100%; AppImage reduces
# dependencies a lot, but glibc/kernel/graphics/audio differences still matter.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="magnus-myggen-leg-og-laer"
DISPLAY_NAME="Magnus & Myggen: Leg og Lær"
ARCH="${ARCH:-x86_64}"
APPDIR="${APPDIR:-$SCRIPT_DIR/build/${PROJECT_NAME}.AppDir}"
DIST_DIR="${DIST_DIR:-$SCRIPT_DIR/dist}"
CACHE_DIR="${CACHE_DIR:-$SCRIPT_DIR/.cache-appimage}"
APPIMAGETOOL_BIN="${APPIMAGETOOL_BIN:-}"
DOWNLOAD_APPIMAGETOOL="${DOWNLOAD_APPIMAGETOOL:-1}"
OUTPUT_APPIMAGE="${OUTPUT_APPIMAGE:-$DIST_DIR/${PROJECT_NAME}-${ARCH}.AppImage}"

GAME_WRAPPER="$SCRIPT_DIR/magnus_myggen_leg_og_laer_launch.sh"
GAME_YAML="$SCRIPT_DIR/magnus-myggen-leg-og-laer-lutris.yml"
GAME_CDROM="$SCRIPT_DIR/cdrom"
GAME_PREFIX="$SCRIPT_DIR/wineprefix32"
GAME_README="$SCRIPT_DIR/README.md"
GAME_ICON_ICO="$SCRIPT_DIR/cdrom/MAGNUS.ICO"

WINE32_BIN="$(command -v wine32 || true)"
WINE_BIN="$(command -v wine || true)"
WINE64_BIN="$(command -v wine64 || true)"
WINESERVER_BIN="$(command -v wineserver || true)"
WINEDBG_BIN="$(command -v winedbg || true)"

log() { printf '[appimage] %s\n' "$*"; }
fatal() { printf '[appimage] ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

sync_tree() {
  local src="$1" dst="$2"
  mkdir -p "$dst"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete "$src/" "$dst/"
  else
    rm -rf "$dst"
    mkdir -p "$dst"
    cp -a "$src/." "$dst/"
  fi
}

usage() {
  cat <<'EOF'
Brug:
  ./build_appimage.sh [--appdir-only] [--no-download]

Miljøvariable:
  APPDIR=...              hvor AppDir bygges
  DIST_DIR=...            output mappe
  OUTPUT_APPIMAGE=...     endelig AppImage-sti
  APPIMAGETOOL_BIN=...    brug specifik appimagetool binær
  DOWNLOAD_APPIMAGETOOL=0 undgå auto-download

Bemærk:
  Scriptet pakker spillet, Wine-runtime, prefix og launcher.
  Lutris pakkes ikke med.
EOF
}

APPDIR_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --appdir-only) APPDIR_ONLY=1 ;;
    --no-download) DOWNLOAD_APPIMAGETOOL=0 ;;
    -h|--help) usage; exit 0 ;;
    *) fatal "Ukendt argument: $1" ;;
  esac
  shift
done

validate_inputs() {
  need python3
  need file
  need ldd
  [[ -x "$GAME_WRAPPER" ]] || fatal "Mangler launcher: $GAME_WRAPPER"
  [[ -d "$GAME_CDROM" ]] || fatal "Mangler cdrom/: $GAME_CDROM"
  [[ -d "$GAME_PREFIX" ]] || fatal "Mangler wineprefix32/: $GAME_PREFIX"
  [[ -n "$WINE32_BIN" || -n "$WINE_BIN" ]] || fatal "Mangler wine32/wine på værtsmaskinen"
}

reset_dirs() {
  rm -rf "$APPDIR"
  mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/lib64" \
           "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/256x256/apps" \
           "$APPDIR/usr/share" \
           "$APPDIR/game" "$DIST_DIR" "$CACHE_DIR"
}

copy_game_files() {
  log "Kopierer spilfiler"
  install -Dm755 "$GAME_WRAPPER" "$APPDIR/game/magnus_myggen_leg_og_laer_launch.sh"
  install -Dm644 "$GAME_YAML" "$APPDIR/game/magnus-myggen-leg-og-laer-lutris.yml"
  install -Dm644 "$GAME_README" "$APPDIR/game/README.md"
  sync_tree "$GAME_CDROM" "$APPDIR/game/cdrom"
  sync_tree "$GAME_PREFIX" "$APPDIR/game/wineprefix32"
  find "$APPDIR/game" -name '*.log' -delete || true
}

copy_optional_bin() {
  local src="$1"
  [[ -n "$src" && -x "$src" ]] || return 0
  install -Dm755 "$src" "$APPDIR/usr/bin/$(basename "$src")"
}

copy_wine_dirs() {
  log "Kopierer Wine-runtime"
  copy_optional_bin "$WINE32_BIN"
  copy_optional_bin "$WINE_BIN"
  copy_optional_bin "$WINE64_BIN"
  copy_optional_bin "$WINESERVER_BIN"
  copy_optional_bin "$WINEDBG_BIN"

  for dir in /usr/lib/wine-wow64 /usr/lib64/wine-wow64; do
    if [[ -d "$dir" ]]; then
      mkdir -p "$APPDIR${dir}"
      cp -a "$dir/." "$APPDIR${dir}/"
    fi
  done

  if [[ -d /usr/share/wine ]]; then
    mkdir -p "$APPDIR/usr/share/wine"
    cp -a /usr/share/wine/. "$APPDIR/usr/share/wine/"
  fi
}

is_elf() {
  local path="$1"
  file -b "$path" 2>/dev/null | grep -q 'ELF'
}

copy_one_dep() {
  local src="$1"
  [[ -e "$src" ]] || return 0
  local dest="$APPDIR$src"
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$src" ]]; then
    local target
    target="$(readlink "$src")"
    if [[ -e "$dest" || -L "$dest" ]]; then
      :
    else
      ln -s "$target" "$dest"
    fi
    if [[ "$target" = /* ]]; then
      copy_one_dep "$target"
    else
      local resolved
      resolved="$(readlink -f "$src")"
      [[ -n "$resolved" ]] && copy_one_dep "$resolved"
    fi
  else
    [[ -e "$dest" ]] || cp -a "$src" "$dest"
  fi
}

collect_deps_from_binary() {
  local bin="$1"
  [[ -e "$bin" ]] || return 0
  ldd "$bin" 2>/dev/null | awk '
    /=> \/|^\// {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^\//) print $i
      }
    }
  ' | while read -r dep; do
    [[ -n "$dep" ]] || continue
    copy_one_dep "$dep"
  done || true
}


collect_runtime_deps() {
  log "Indsamler ELF-afhængigheder"
  local tmp_list="$CACHE_DIR/elf-files.txt"
  : > "$tmp_list"

  find "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/lib64" -type f 2>/dev/null | while read -r f; do
    if is_elf "$f"; then
      printf '%s\n' "$f" >> "$tmp_list"
    fi
  done || true

  while read -r elf; do
    [[ -n "$elf" ]] || continue
    collect_deps_from_binary "$elf"
  done < "$tmp_list" || true

  # Ensure dynamic loaders exist inside AppDir if host deps referenced them.
  for loader in /lib/ld-linux.so.2 /lib64/ld-linux-x86-64.so.2; do
    [[ -e "$loader" ]] && copy_one_dep "$loader"
  done
}

write_launcher_scripts() {
  log "Skriver AppRun og intern launcher"
  cat > "$APPDIR/usr/bin/${PROJECT_NAME}" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export APPDIR="$HERE"
APP_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/magnus-myggen-leg-og-laer"
RUNTIME_PREFIX="$APP_STATE_DIR/wineprefix32"
mkdir -p "$APP_STATE_DIR"
if [[ ! -f "$RUNTIME_PREFIX/system.reg" ]]; then
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$HERE/game/wineprefix32/" "$RUNTIME_PREFIX/"
  else
    mkdir -p "$RUNTIME_PREFIX"
    cp -a "$HERE/game/wineprefix32/." "$RUNTIME_PREFIX/"
  fi
fi
export WINEPREFIX="$RUNTIME_PREFIX"
export MM1_WINEPREFIX="$WINEPREFIX"
export MM1_CD_DIR="$HERE/game/cdrom"
export MM1_ISO_PATH="$HERE/game/Magnus-Myggen-Leg-og-Laer.iso"
export MM1_CENTER_WINDOW="0"
export MM1_MODE="${MM1_MODE:-game}"
export MM1_USE_LOOP_CDROM="${MM1_USE_LOOP_CDROM:-0}"
export MM1_WINVER="win98"
export MM1_LOCK_FILE="$APP_STATE_DIR/.mm1-launch.lock"
export MM1_PREFER_BUNDLED_WINE="${MM1_PREFER_BUNDLED_WINE:-1}"
USE_BUNDLED_WINE=0
BUNDLED_WINE32="$HERE/usr/lib/wine-wow64/wine/i386-unix/wine"
BUNDLED_WINE64="$HERE/usr/lib64/wine-wow64/wine/x86_64-unix/wine"
BUNDLED_WINE32_WRAPPER="$HERE/usr/bin/wine32"
BUNDLED_WINE_WRAPPER="$HERE/usr/bin/wine"
if [[ -n "${MM1_WINE_BIN:-}" ]]; then
  :
elif [[ "${MM1_PREFER_BUNDLED_WINE:-0}" == "1" ]]; then
  if [[ -x "$BUNDLED_WINE32" ]]; then
    export MM1_WINE_BIN="$BUNDLED_WINE32"
    USE_BUNDLED_WINE=1
  elif [[ -x "$BUNDLED_WINE64" ]]; then
    export MM1_WINE_BIN="$BUNDLED_WINE64"
    USE_BUNDLED_WINE=1
  elif [[ -x "$BUNDLED_WINE32_WRAPPER" ]]; then
    export MM1_WINE_BIN="$BUNDLED_WINE32_WRAPPER"
    USE_BUNDLED_WINE=1
  elif [[ -x "$BUNDLED_WINE_WRAPPER" ]]; then
    export MM1_WINE_BIN="$BUNDLED_WINE_WRAPPER"
    USE_BUNDLED_WINE=1
  fi
elif [[ -x /usr/bin/wine32 ]]; then
  export MM1_WINE_BIN="/usr/bin/wine32"
elif [[ -x /usr/bin/wine ]]; then
  export MM1_WINE_BIN="/usr/bin/wine"
elif [[ -x "$BUNDLED_WINE32" ]]; then
  export MM1_WINE_BIN="$BUNDLED_WINE32"
  USE_BUNDLED_WINE=1
elif [[ -x "$BUNDLED_WINE64" ]]; then
  export MM1_WINE_BIN="$BUNDLED_WINE64"
  USE_BUNDLED_WINE=1
elif [[ -x "$BUNDLED_WINE32_WRAPPER" ]]; then
  export MM1_WINE_BIN="$BUNDLED_WINE32_WRAPPER"
  USE_BUNDLED_WINE=1
elif [[ -x "$BUNDLED_WINE_WRAPPER" ]]; then
  export MM1_WINE_BIN="$BUNDLED_WINE_WRAPPER"
  USE_BUNDLED_WINE=1
fi
if [[ "$USE_BUNDLED_WINE" == "1" ]]; then
  export WINEDLLPATH="$HERE/usr/lib/wine-wow64:$HERE/usr/lib64/wine-wow64${WINEDLLPATH:+:$WINEDLLPATH}"
  export LD_LIBRARY_PATH="$HERE/usr/lib:$HERE/usr/lib64:/lib:/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
fi
export PATH="$HERE/usr/bin:$PATH"
cd "$HERE/game"
exec "$HERE/game/magnus_myggen_leg_og_laer_launch.sh" "$@"
EOF
  chmod +x "$APPDIR/usr/bin/${PROJECT_NAME}"

  cat > "$APPDIR/AppRun" <<EOF
#!/usr/bin/env bash
exec "\$(cd "\$(dirname "\$0")" && pwd)/usr/bin/${PROJECT_NAME}" "\$@"
EOF
  chmod +x "$APPDIR/AppRun"
}

write_desktop_file() {
  cat > "$APPDIR/${PROJECT_NAME}.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=${DISPLAY_NAME}
Exec=${PROJECT_NAME}
Icon=${PROJECT_NAME}
Categories=Game;
Terminal=false
EOF
  cp "$APPDIR/${PROJECT_NAME}.desktop" "$APPDIR/usr/share/applications/${PROJECT_NAME}.desktop"
}

write_icon() {
  log "Genererer ikon"
  if [[ -f "$GAME_ICON_ICO" ]]; then
    python3 - "$GAME_ICON_ICO" "$APPDIR/usr/share/icons/hicolor" "$PROJECT_NAME" <<'PY'
from PIL import Image
import sys
from pathlib import Path

src, icon_root, project_name = sys.argv[1:4]
im = Image.open(src)
im = im.convert('RGBA')

sizes = [32, 48, 64, 128, 256]
root = Path(icon_root)

# The source ICO only contains a 32x32 frame. AppImage/file-manager icons look
# tiny if we merely center that 32x32 bitmap on a transparent 256x256 canvas.
# Scale it up to each target size so the AppImage file itself gets a normal,
# full-size icon in desktop file managers.
for size in sizes:
    out_dir = root / f'{size}x{size}' / 'apps'
    out_dir.mkdir(parents=True, exist_ok=True)
    resized = im.resize((size, size), Image.Resampling.LANCZOS)
    resized.save(out_dir / f'{project_name}.png')
PY
    cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png" "$APPDIR/.DirIcon"
    cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png" "$APPDIR/${PROJECT_NAME}.png"
  else
    python3 - "$APPDIR/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png" <<'PY'
from PIL import Image, ImageDraw
import sys
out = sys.argv[1]
im = Image.new('RGBA', (256,256), (37, 44, 72, 255))
d = ImageDraw.Draw(im)
d.rectangle((18,18,238,238), outline=(255,255,255,255), width=6)
d.text((42, 104), 'MM1', fill=(255,255,255,255))
im.save(out)
PY
    cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png" "$APPDIR/.DirIcon"
    cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png" "$APPDIR/${PROJECT_NAME}.png"
  fi
}

resolve_appimagetool() {
  if [[ -n "$APPIMAGETOOL_BIN" && -x "$APPIMAGETOOL_BIN" ]]; then
    return 0
  fi
  if command -v appimagetool >/dev/null 2>&1; then
    APPIMAGETOOL_BIN="$(command -v appimagetool)"
    return 0
  fi
  [[ "$DOWNLOAD_APPIMAGETOOL" == "1" ]] || return 1

  APPIMAGETOOL_BIN="$CACHE_DIR/appimagetool-${ARCH}.AppImage"
  if [[ ! -x "$APPIMAGETOOL_BIN" ]]; then
    log "Downloader appimagetool"
    curl -L -o "$APPIMAGETOOL_BIN" \
      "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${ARCH}.AppImage"
    chmod +x "$APPIMAGETOOL_BIN"
  fi
}

build_appimage() {
  resolve_appimagetool || fatal "appimagetool mangler. Installer det eller kør med --appdir-only"
  log "Bygger AppImage"

  local tool_runner="$APPIMAGETOOL_BIN"
  if [[ "$APPIMAGETOOL_BIN" == *.AppImage ]]; then
    local extracted="$CACHE_DIR/appimagetool-squashfs-root/AppRun"
    if [[ ! -x "$extracted" ]]; then
      log "Udpakker appimagetool lokalt (FUSE workaround)"
      rm -rf "$CACHE_DIR/appimagetool-squashfs-root" "$CACHE_DIR/squashfs-root"
      (
        cd "$CACHE_DIR"
        "$APPIMAGETOOL_BIN" --appimage-extract >/dev/null
        mv squashfs-root appimagetool-squashfs-root
      )
    fi
    tool_runner="$extracted"
  fi

  ARCH="$ARCH" "$tool_runner" "$APPDIR" "$OUTPUT_APPIMAGE"
  log "Færdig: $OUTPUT_APPIMAGE"
}

summarize() {
  log "AppDir klar: $APPDIR"
  du -sh "$APPDIR" 2>/dev/null || true
  if [[ -f "$OUTPUT_APPIMAGE" ]]; then
    ls -lh "$OUTPUT_APPIMAGE"
  fi
}

main() {
  validate_inputs
  reset_dirs
  copy_game_files
  # Keep ISO optional. If present, bundle it too for loop-mount capable launches.
  if [[ -f "$SCRIPT_DIR/Magnus-Myggen-Leg-og-Laer.iso" ]]; then
    install -Dm644 "$SCRIPT_DIR/Magnus-Myggen-Leg-og-Laer.iso" "$APPDIR/game/Magnus-Myggen-Leg-og-Laer.iso"
  fi
  copy_wine_dirs
  collect_runtime_deps
  write_launcher_scripts
  write_desktop_file
  write_icon
  if [[ "$APPDIR_ONLY" == "0" ]]; then
    build_appimage
  fi
  summarize
}

main "$@"
