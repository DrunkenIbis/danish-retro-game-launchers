#!/usr/bin/env bash
# Generic AppDir/AppImage builder helpers for Wine-based game recipes.
#
# A per-game extras/build_appimage.sh should set at least:
#   PROJECT_NAME="game-slug"
#   DISPLAY_NAME="Human Game Name"
#   GAME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
#   APPDIR=... DIST_DIR=... CACHE_DIR=... OUTPUT_APPIMAGE=...
# Then source this file and call the functions from its main().

set -Eeuo pipefail

wine_appimage_log() { printf '[appimage] %s\n' "$*"; }
wine_appimage_fatal() { printf '[appimage] ERROR: %s\n' "$*" >&2; exit 1; }
wine_appimage_need() { command -v "$1" >/dev/null 2>&1 || wine_appimage_fatal "Mangler kommando: $1"; }

wine_appimage_init_defaults() {
  [[ -n "${PROJECT_NAME:-}" ]] || wine_appimage_fatal "PROJECT_NAME mangler"
  [[ -n "${DISPLAY_NAME:-}" ]] || wine_appimage_fatal "DISPLAY_NAME mangler"
  ARCH="${ARCH:-x86_64}"
  APPIMAGETOOL_BIN="${APPIMAGETOOL_BIN:-}"
  DOWNLOAD_APPIMAGETOOL="${DOWNLOAD_APPIMAGETOOL:-1}"
  APPDIR_ONLY="${APPDIR_ONLY:-0}"
  STATE_DIR_BASENAME="${STATE_DIR_BASENAME:-$PROJECT_NAME}"
  PREFIX_SEED_REL="${PREFIX_SEED_REL:-game/wineprefix}"
  INTERNAL_LAUNCHER_REL="${INTERNAL_LAUNCHER_REL:-game/appimage-launch.sh}"
}

wine_appimage_sync_tree() {
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

wine_appimage_validate_base_tools() {
  wine_appimage_need bash
  wine_appimage_need file
  wine_appimage_need ldd
  wine_appimage_need python3
}

wine_appimage_reset_dirs() {
  rm -rf "$APPDIR"
  mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/lib64" \
           "$APPDIR/usr/share/applications" \
           "$APPDIR/usr/share/icons/hicolor/256x256/apps" \
           "$APPDIR/usr/share" "$APPDIR/game" "$DIST_DIR" "$CACHE_DIR"
}

wine_appimage_copy_optional_bin() {
  local src="$1"
  [[ -n "$src" && -x "$src" ]] || return 0
  install -Dm755 "$src" "$APPDIR/usr/bin/$(basename "$src")"
}

wine_appimage_copy_wine_runtime() {
  wine_appimage_log "Kopierer Wine-runtime"
  local wine32_bin wine_bin wine64_bin wineserver_bin winedbg_bin
  wine32_bin="$(command -v wine32 || true)"
  wine_bin="$(command -v wine || true)"
  wine64_bin="$(command -v wine64 || true)"
  wineserver_bin="$(command -v wineserver || true)"
  winedbg_bin="$(command -v winedbg || true)"

  [[ -n "$wine32_bin" || -n "$wine_bin" ]] || wine_appimage_fatal "Mangler wine32/wine på build-maskinen"
  wine_appimage_copy_optional_bin "$wine32_bin"
  wine_appimage_copy_optional_bin "$wine_bin"
  wine_appimage_copy_optional_bin "$wine64_bin"
  wine_appimage_copy_optional_bin "$wineserver_bin"
  wine_appimage_copy_optional_bin "$winedbg_bin"

  local dir
  for dir in /usr/lib/wine-wow64 /usr/lib64/wine-wow64 /usr/lib/wine /usr/lib64/wine; do
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

wine_appimage_is_elf() {
  file -b "$1" 2>/dev/null | grep -q 'ELF'
}

wine_appimage_copy_one_dep() {
  local src="$1"
  [[ -e "$src" ]] || return 0
  local dest="$APPDIR$src"
  mkdir -p "$(dirname "$dest")"
  if [[ -L "$src" ]]; then
    local target resolved
    target="$(readlink "$src")"
    [[ -e "$dest" || -L "$dest" ]] || ln -s "$target" "$dest"
    if [[ "$target" = /* ]]; then
      wine_appimage_copy_one_dep "$target"
    else
      resolved="$(readlink -f "$src")"
      [[ -n "$resolved" ]] && wine_appimage_copy_one_dep "$resolved"
    fi
  else
    [[ -e "$dest" ]] || cp -a "$src" "$dest"
  fi
}

wine_appimage_collect_deps_from_binary() {
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
    wine_appimage_copy_one_dep "$dep"
  done || true
}

wine_appimage_collect_runtime_deps() {
  wine_appimage_log "Indsamler ELF-afhængigheder"
  local tmp_list="$CACHE_DIR/elf-files.txt"
  : > "$tmp_list"

  find "$APPDIR/usr/bin" "$APPDIR/usr/lib" "$APPDIR/usr/lib64" -type f 2>/dev/null | while read -r f; do
    if wine_appimage_is_elf "$f"; then
      printf '%s\n' "$f" >> "$tmp_list"
    fi
  done || true

  while read -r elf; do
    [[ -n "$elf" ]] || continue
    wine_appimage_collect_deps_from_binary "$elf"
  done < "$tmp_list" || true

  local loader
  for loader in /lib/ld-linux.so.2 /lib64/ld-linux-x86-64.so.2; do
    [[ -e "$loader" ]] && wine_appimage_copy_one_dep "$loader"
  done
}

wine_appimage_write_runner_scripts() {
  wine_appimage_log "Skriver AppRun og generisk Wine runner"
  cat > "$APPDIR/usr/bin/${PROJECT_NAME}" <<EOF
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")/../.." && pwd)"
export APPDIR="\$HERE"
APP_STATE_DIR="\${XDG_DATA_HOME:-\$HOME/.local/share}/${STATE_DIR_BASENAME}"
RUNTIME_PREFIX="\$APP_STATE_DIR/wineprefix"
SEED_PREFIX="\$HERE/${PREFIX_SEED_REL}"
LOCK_FILE="\$APP_STATE_DIR/.appimage-launch.lock"
mkdir -p "\$APP_STATE_DIR"
(
  flock 9
  if [[ ! -f "\$RUNTIME_PREFIX/system.reg" ]]; then
    rm -rf "\$RUNTIME_PREFIX"
    mkdir -p "\$RUNTIME_PREFIX"
    # Use cp for the seeded Wine prefix at launch time. Some prefixes contain
    # legacy dosdevices symlinks to /dev/loop* or disappeared mount points;
    # rsync can exit 13 on those from inside/extracted AppImages before the
    # game launcher has a chance to rewrite d:/d::. cp -a preserves the tree
    # well enough, and each game launcher cleans/remaps its active CD drive.
    cp -a "\$SEED_PREFIX/." "\$RUNTIME_PREFIX/"
  fi
) 9>"\$LOCK_FILE"

export WINEPREFIX="\$RUNTIME_PREFIX"
export PATH="\$HERE/usr/bin:\$PATH"
USE_BUNDLED_WINE=0
BUNDLED_WINE32="\$HERE/usr/lib/wine-wow64/wine/i386-unix/wine"
BUNDLED_WINE64="\$HERE/usr/lib64/wine-wow64/wine/x86_64-unix/wine"
BUNDLED_WINE32_WRAPPER="\$HERE/usr/bin/wine32"
BUNDLED_WINE_WRAPPER="\$HERE/usr/bin/wine"
if [[ -n "\${APPIMAGE_WINE_BIN:-}" ]]; then
  export WINE_BIN="\$APPIMAGE_WINE_BIN"
elif [[ "\${APPIMAGE_PREFER_HOST_WINE:-0}" == "1" ]]; then
  if command -v wine32 >/dev/null 2>&1; then
    export WINE_BIN="\$(command -v wine32)"
  elif command -v wine >/dev/null 2>&1; then
    export WINE_BIN="\$(command -v wine)"
  fi
fi
if [[ -z "\${WINE_BIN:-}" ]]; then
  if [[ -x "\$BUNDLED_WINE32" ]]; then
    export WINE_BIN="\$BUNDLED_WINE32"
    USE_BUNDLED_WINE=1
  elif [[ -x "\$BUNDLED_WINE64" ]]; then
    export WINE_BIN="\$BUNDLED_WINE64"
    USE_BUNDLED_WINE=1
  elif [[ -x "\$BUNDLED_WINE32_WRAPPER" ]]; then
    export WINE_BIN="\$BUNDLED_WINE32_WRAPPER"
    USE_BUNDLED_WINE=1
  elif [[ -x "\$BUNDLED_WINE_WRAPPER" ]]; then
    export WINE_BIN="\$BUNDLED_WINE_WRAPPER"
    USE_BUNDLED_WINE=1
  elif command -v wine32 >/dev/null 2>&1; then
    export WINE_BIN="\$(command -v wine32)"
  elif command -v wine >/dev/null 2>&1; then
    export WINE_BIN="\$(command -v wine)"
  else
    echo "No bundled or host Wine found" >&2
    exit 1
  fi
fi
if [[ "\$USE_BUNDLED_WINE" == "1" ]]; then
  export WINEDLLPATH="\$HERE/usr/lib/wine-wow64:\$HERE/usr/lib64/wine-wow64:\$HERE/usr/lib/wine:\$HERE/usr/lib64/wine\${WINEDLLPATH:+:\$WINEDLLPATH}"
  export LD_LIBRARY_PATH="\$HERE/usr/lib:\$HERE/usr/lib64:/lib:/lib64:/usr/lib:/usr/lib64\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
  export XDG_DATA_DIRS="\$HERE/usr/share\${XDG_DATA_DIRS:+:\$XDG_DATA_DIRS}"
fi
cd "\$HERE/game"
exec "\$HERE/${INTERNAL_LAUNCHER_REL}" "\$@"
EOF
  chmod +x "$APPDIR/usr/bin/${PROJECT_NAME}"

  cat > "$APPDIR/AppRun" <<EOF
#!/usr/bin/env bash
exec "\$(cd "\$(dirname "\$0")" && pwd)/usr/bin/${PROJECT_NAME}" "\$@"
EOF
  chmod +x "$APPDIR/AppRun"
}

wine_appimage_write_desktop_file() {
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

wine_appimage_write_fallback_icon_png() {
  local out="$1"
  python3 - "$out" <<'PY'
from pathlib import Path
import struct, sys, zlib
out = Path(sys.argv[1])
w = h = 256
raw = bytearray()
for y in range(h):
    raw.append(0)
    for x in range(w):
        r = 45 + (x * 80 // w)
        g = 65 + (y * 60 // h)
        b = 120
        if 38 < x < 218 and 88 < y < 168:
            r, g, b = 230, 230, 245
        raw.extend((r, g, b, 255))
def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
png += chunk(b'IEND', b'')
out.parent.mkdir(parents=True, exist_ok=True)
out.write_bytes(png)
PY
}

wine_appimage_write_icon() {
  local source_icon="${1:-}"
  wine_appimage_log "Genererer ikon"
  local out="$APPDIR/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png"
  mkdir -p "$(dirname "$out")"
  if [[ -n "$source_icon" && -f "$source_icon" ]]; then
    if python3 - "$source_icon" "$APPDIR/usr/share/icons/hicolor" "$PROJECT_NAME" <<'PY'
from pathlib import Path
import sys
try:
    from PIL import Image
except Exception as exc:
    raise SystemExit(f'PIL missing: {exc}')
src, root, name = sys.argv[1:4]
im = Image.open(src)
# Pick the largest frame available in ICO files.
best = None
for i in range(getattr(im, 'n_frames', 1)):
    im.seek(i)
    frame = im.convert('RGBA')
    if best is None or frame.size[0] * frame.size[1] > best.size[0] * best.size[1]:
        best = frame.copy()
for size in (16, 32, 48, 64, 128, 256):
    out_dir = Path(root) / f'{size}x{size}' / 'apps'
    out_dir.mkdir(parents=True, exist_ok=True)
    best.resize((size, size), Image.Resampling.LANCZOS).save(out_dir / f'{name}.png')
PY
    then
      :
    elif command -v convert >/dev/null 2>&1; then
      convert "$source_icon" -resize 256x256 "$out" || wine_appimage_write_fallback_icon_png "$out"
    elif command -v magick >/dev/null 2>&1; then
      magick "$source_icon" -resize 256x256 "$out" || wine_appimage_write_fallback_icon_png "$out"
    else
      wine_appimage_write_fallback_icon_png "$out"
    fi
  else
    wine_appimage_write_fallback_icon_png "$out"
  fi
  [[ -f "$out" ]] || wine_appimage_write_fallback_icon_png "$out"
  cp "$out" "$APPDIR/.DirIcon"
  cp "$out" "$APPDIR/${PROJECT_NAME}.png"
}

wine_appimage_resolve_appimagetool() {
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
    wine_appimage_need curl
    wine_appimage_log "Downloader appimagetool"
    curl -L -o "$APPIMAGETOOL_BIN" \
      "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-${ARCH}.AppImage"
    chmod +x "$APPIMAGETOOL_BIN"
  fi
}

wine_appimage_build_appimage() {
  wine_appimage_resolve_appimagetool || wine_appimage_fatal "appimagetool mangler. Installer det eller kør med --appdir-only"
  wine_appimage_log "Bygger AppImage"
  local tool_runner="$APPIMAGETOOL_BIN"
  if [[ "$APPIMAGETOOL_BIN" == *.AppImage ]]; then
    local extracted="$CACHE_DIR/appimagetool-squashfs-root/AppRun"
    if [[ ! -x "$extracted" ]]; then
      wine_appimage_log "Udpakker appimagetool lokalt (FUSE workaround)"
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
  wine_appimage_log "Færdig: $OUTPUT_APPIMAGE"
}

wine_appimage_verify_appdir() {
  wine_appimage_log "Verificerer AppDir metadata"
  stat "$APPDIR/AppRun" "$APPDIR/${PROJECT_NAME}.desktop" "$APPDIR/.DirIcon" \
       "$APPDIR/${PROJECT_NAME}.png" \
       "$APPDIR/usr/share/applications/${PROJECT_NAME}.desktop" \
       "$APPDIR/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png" >/dev/null
  grep -q "^Icon=${PROJECT_NAME}$" "$APPDIR/${PROJECT_NAME}.desktop"
  grep -q "^Icon=${PROJECT_NAME}$" "$APPDIR/usr/share/applications/${PROJECT_NAME}.desktop"
  file "$APPDIR/.DirIcon" | grep -q 'PNG image data'
}

wine_appimage_summarize() {
  wine_appimage_log "AppDir klar: $APPDIR"
  du -sh "$APPDIR" 2>/dev/null || true
  if [[ -f "$OUTPUT_APPIMAGE" ]]; then
    ls -lh "$OUTPUT_APPIMAGE"
  fi
}
