#!/usr/bin/env bash
set -Eeuo pipefail

# Build an AppDir/AppImage that bundles Det Magiske Jordbær + the official
# DOSBox-Staging Linux runtime.
#
# NOTE: An AppImage can run on many Linux distributions, but never literally all
# of them. The bundled DOSBox-Staging release is x86_64 and still relies on a
# compatible kernel/glibc plus host ALSA/OpenGL, as documented upstream.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAME_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$GAME_DIR/../.." && pwd)"

PROJECT_NAME="det-magiske-jordbaer"
DISPLAY_NAME="Det Magiske Jordbær"
ARCH="${ARCH:-x86_64}"
APPDIR="${APPDIR:-$SCRIPT_DIR/build/${PROJECT_NAME}.AppDir}"
DIST_DIR="${DIST_DIR:-$SCRIPT_DIR/dist}"
CACHE_DIR="${CACHE_DIR:-$SCRIPT_DIR/.cache-appimage}"
OUTPUT_APPIMAGE="${OUTPUT_APPIMAGE:-$DIST_DIR/${PROJECT_NAME}-${ARCH}.AppImage}"
APPIMAGETOOL_BIN="${APPIMAGETOOL_BIN:-}"
DOWNLOAD_APPIMAGETOOL="${DOWNLOAD_APPIMAGETOOL:-1}"

DOSBOX_VERSION="${DOSBOX_VERSION:-0.82.2}"
DOSBOX_TARBALL_URL="${DOSBOX_TARBALL_URL:-https://github.com/dosbox-staging/dosbox-staging/releases/download/v${DOSBOX_VERSION}/dosbox-staging-linux-x86_64-v${DOSBOX_VERSION}.tar.xz}"
DOSBOX_TARBALL_SHA256="${DOSBOX_TARBALL_SHA256:-bc229df72ea103b7865cdca67324772dbffa8e58866477e69a79638b723a0442}"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
RUNTIME_DIR="${DMJ_RUNTIME_DIR:-$RUNTIME_BASE/$PROJECT_NAME}"
ISO="${DMJ_ISO:-$SOURCE_BASE/$PROJECT_NAME/DetMagiskeJordbaer.iso}"
CDROM="${DMJ_CDROM:-$RUNTIME_DIR/cdrom}"
GAME="${DMJ_GAME_DIR:-$RUNTIME_DIR/game}"

APPDIR_ONLY=0

log() { printf '[appimage] %s\n' "$*"; }
fatal() { printf '[appimage] ERROR: %s\n' "$*" >&2; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

usage() {
  cat <<'EOF'
Brug:
  ./extras/build_appimage.sh [--appdir-only] [--no-download]

Bygger en selvstændig AppDir/AppImage for Det Magiske Jordbær.
Scriptet pakker:
  - de lokalt udtrukne spilfiler fra local/runtime/det-magiske-jordbaer/
  - official DOSBox-Staging Linux x86_64 runtime
  - en AppImage launcher med de lydindstillinger der reducerer knitring

Miljøvariable:
  DMJ_ISO=...              ISO der kan udtrækkes hvis runtime mangler
  DMJ_RUNTIME_DIR=...      runtime mappe med game/ og cdrom/
  RETRO_GAME_SOURCE_DIR=... standard kildebase, hvis DMJ_ISO ikke sættes
  RETRO_GAME_RUNTIME_DIR=... standard runtimebase, hvis DMJ_RUNTIME_DIR ikke sættes
  APPDIR=...               hvor AppDir bygges
  DIST_DIR=...             output mappe
  OUTPUT_APPIMAGE=...      endelig AppImage-sti
  APPIMAGETOOL_BIN=...     brug specifik appimagetool binær
  DOWNLOAD_APPIMAGETOOL=0  undgå auto-download af appimagetool

Bemærk:
  AppImage-filen kommer til at indeholde spilfilerne. Byg/distribuér den kun
  hvis du har rettigheder til den konkrete kopi af spillet.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --appdir-only) APPDIR_ONLY=1 ;;
    --no-download) DOWNLOAD_APPIMAGETOOL=0 ;;
    -h|--help) usage; exit 0 ;;
    *) fatal "Ukendt argument: $1" ;;
  esac
  shift
done

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

validate_tools() {
  need bash
  need curl
  need tar
  need sha256sum
  need python3
  need file
}

prepare_runtime_from_iso_if_needed() {
  if [[ -f "$GAME/ADVENT.EXE" && -f "$CDROM/ADVENT.RES" ]]; then
    return 0
  fi

  [[ -f "$ISO" ]] || fatal "Runtime mangler og ISO blev ikke fundet: $ISO. Kør ./install.sh først eller sæt DMJ_ISO=/sti/til/DetMagiskeJordbaer.iso"
  need 7z

  log "Forbereder runtime fra ISO: $ISO"
  mkdir -p "$CDROM" "$GAME" "$RUNTIME_DIR/logs"
  7z x -y -o"$CDROM" "$ISO" >"$RUNTIME_DIR/logs/appimage-extract.log"

  for f in EGAVGA.BGI DETECT.EXE DOS4GW.EXE WINRUN.EXE STRMGC.ICN STRMGC.SND ADVENT.EXE ERRORS.BIN SETSOUND.EXE ADVENT.INI ADVENT.000 ADVENT.RTS GLOBAL.SET STR.ID; do
    if [[ -f "$CDROM/$f" ]]; then
      cp -f "$CDROM/$f" "$GAME/$f"
    fi
  done
}

validate_inputs() {
  validate_tools
  prepare_runtime_from_iso_if_needed
  [[ -f "$GAME/ADVENT.EXE" ]] || fatal "Mangler game/ADVENT.EXE i $GAME"
  [[ -f "$CDROM/ADVENT.RES" ]] || fatal "Mangler cdrom/ADVENT.RES i $CDROM"
}

reset_dirs() {
  rm -rf "$APPDIR"
  mkdir -p "$APPDIR/usr/bin" \
           "$APPDIR/usr/share/applications" \
           "$APPDIR/usr/share/icons/hicolor/256x256/apps" \
           "$APPDIR/usr/share/dosbox-staging" \
           "$APPDIR/game" "$DIST_DIR" "$CACHE_DIR"
}

download_dosbox_runtime() {
  local tarball="$CACHE_DIR/dosbox-staging-${DOSBOX_VERSION}-${ARCH}.tar.xz"
  local extract_dir="$CACHE_DIR/dosbox-staging-${DOSBOX_VERSION}-${ARCH}"

  if [[ ! -f "$tarball" ]]; then
    log "Downloader DOSBox-Staging ${DOSBOX_VERSION}"
    curl -L -o "$tarball" "$DOSBOX_TARBALL_URL"
  fi

  local got_sha
  got_sha="$(sha256sum "$tarball" | awk '{print $1}')"
  [[ "$got_sha" == "$DOSBOX_TARBALL_SHA256" ]] || fatal "Forkert SHA256 for $tarball: $got_sha"

  if [[ ! -x "$extract_dir/dosbox" ]]; then
    rm -rf "$extract_dir" "$CACHE_DIR/dosbox-staging-unpack"
    mkdir -p "$CACHE_DIR/dosbox-staging-unpack"
    tar -xf "$tarball" -C "$CACHE_DIR/dosbox-staging-unpack"
    local top
    top="$(find "$CACHE_DIR/dosbox-staging-unpack" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [[ -n "$top" && -x "$top/dosbox" ]] || fatal "Kunne ikke finde dosbox i DOSBox-Staging tarball"
    mv "$top" "$extract_dir"
    rm -rf "$CACHE_DIR/dosbox-staging-unpack"
  fi

  DOSBOX_RUNTIME_DIR="$extract_dir"
}

copy_dosbox_runtime() {
  log "Kopierer DOSBox-Staging runtime"
  download_dosbox_runtime
  install -Dm755 "$DOSBOX_RUNTIME_DIR/dosbox" "$APPDIR/usr/bin/dosbox"
  if [[ -d "$DOSBOX_RUNTIME_DIR/resources" ]]; then
    # The official tarball keeps resources next to the dosbox binary. Keep that
    # sibling layout too; otherwise unicode mapping files are not found when the
    # binary is moved into AppDir/usr/bin.
    sync_tree "$DOSBOX_RUNTIME_DIR/resources" "$APPDIR/usr/bin/resources"
    sync_tree "$DOSBOX_RUNTIME_DIR/resources" "$APPDIR/usr/share/dosbox-staging/resources"
  fi
  if [[ -d "$DOSBOX_RUNTIME_DIR/doc/licenses" ]]; then
    sync_tree "$DOSBOX_RUNTIME_DIR/doc/licenses" "$APPDIR/usr/share/doc/dosbox-staging/licenses"
  fi
}

copy_game_files() {
  log "Kopierer spilfiler"
  sync_tree "$CDROM" "$APPDIR/game/cdrom"
  sync_tree "$GAME" "$APPDIR/game/game-template"
  find "$APPDIR/game" -name '*.log' -delete || true
  install -Dm644 "$GAME_DIR/README.md" "$APPDIR/game/README.md"
}

write_internal_config_template() {
  cat > "$APPDIR/game/det-magiske-jordbaer-appimage.conf.in" <<'EOF'
[sdl]
fullscreen = false
windowresolution = 800x600
output = texture

[dosbox]
machine = svga_s3
memsize = 16

[voodoo]
voodoo = false

[ethernet]
ne2000 = false

[cpu]
cpu_cycles = 12000

[mixer]
rate = 48000
blocksize = 1024
prebuffer = 80
negotiate = false

[sblaster]
sbtype = sb16
sbbase = 220
irq = 7
dma = 1
hdma = 5

[autoexec]
@echo off
mount c "__STATE_GAME__"
mount d "__APP_CDROM__" -t cdrom
c:
set dos4g=quiet
ADVENT -L0
exit
EOF
}

write_launcher_scripts() {
  log "Skriver AppRun og intern launcher"
  cat > "$APPDIR/usr/bin/${PROJECT_NAME}" <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_STATE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/det-magiske-jordbaer"
STATE_GAME="$APP_STATE_DIR/game"
CONF="$APP_STATE_DIR/det-magiske-jordbaer.conf"
LOCK_FILE="$APP_STATE_DIR/.launch.lock"
mkdir -p "$APP_STATE_DIR"

# The AppImage mount is read-only. Keep the writable C: drive in the user's data
# directory so save games and ADVENT.INI changes survive between launches.
(
  flock 9
  if [[ ! -f "$STATE_GAME/ADVENT.EXE" ]]; then
    rm -rf "$STATE_GAME"
    mkdir -p "$STATE_GAME"
    cp -a "$HERE/game/game-template/." "$STATE_GAME/"
  fi
) 9>"$LOCK_FILE"

python3 - "$HERE/game/det-magiske-jordbaer-appimage.conf.in" "$CONF" "$STATE_GAME" "$HERE/game/cdrom" <<'PY'
from pathlib import Path
import sys
src, dst, state_game, cdrom = map(Path, sys.argv[1:])
text = src.read_text()
text = text.replace('__STATE_GAME__', str(state_game))
text = text.replace('__APP_CDROM__', str(cdrom))
dst.write_text(text)
PY

export DOSBOX_RESOURCES="$HERE/usr/share/dosbox-staging/resources"
export PATH="$HERE/usr/bin:$PATH"
exec "$HERE/usr/bin/dosbox" -conf "$CONF" -noconsole "$@"
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
  python3 - "$APPDIR/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png" <<'PY'
from pathlib import Path
import struct, sys, zlib
out = Path(sys.argv[1])
w = h = 256
raw = bytearray()
for y in range(h):
    raw.append(0)
    for x in range(w):
        # Strawberry-ish radial background with simple green top.
        cx, cy = x - 128, y - 136
        dist = min(1.0, (cx*cx + cy*cy) ** 0.5 / 170)
        r = int(235 - 60 * dist)
        g = int(42 + 20 * (1 - dist))
        b = int(70 + 25 * dist)
        if 38 < y < 95 and abs(x - 128) < 75 - (y - 38) // 2:
            r, g, b = 54, 145, 72
        if 65 < y < 220 and ((x - 128) ** 2 / 86 ** 2 + (y - 142) ** 2 / 96 ** 2) < 1:
            r, g, b = 220, 36, 58
            if (x * 13 + y * 7) % 37 < 2:
                r, g, b = 255, 230, 135
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
  cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png" "$APPDIR/.DirIcon"
  cp "$APPDIR/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png" "$APPDIR/${PROJECT_NAME}.png"
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

verify_appdir() {
  log "Verificerer AppDir metadata"
  stat "$APPDIR/AppRun" "$APPDIR/${PROJECT_NAME}.desktop" "$APPDIR/.DirIcon" \
       "$APPDIR/${PROJECT_NAME}.png" \
       "$APPDIR/usr/share/applications/${PROJECT_NAME}.desktop" \
       "$APPDIR/usr/share/icons/hicolor/256x256/apps/${PROJECT_NAME}.png" >/dev/null
  grep -q "^Icon=${PROJECT_NAME}$" "$APPDIR/${PROJECT_NAME}.desktop"
  grep -q "^Icon=${PROJECT_NAME}$" "$APPDIR/usr/share/applications/${PROJECT_NAME}.desktop"
  file "$APPDIR/.DirIcon" | grep -q 'PNG image data'
  "$APPDIR/usr/bin/dosbox" --version >/dev/null
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
  copy_dosbox_runtime
  copy_game_files
  write_internal_config_template
  write_launcher_scripts
  write_desktop_file
  write_icon
  verify_appdir
  if [[ "$APPDIR_ONLY" == "0" ]]; then
    build_appimage
  fi
  summarize
}

main "$@"
