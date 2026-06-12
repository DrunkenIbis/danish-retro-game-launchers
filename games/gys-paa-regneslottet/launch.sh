#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZIP="${GYS_ZIP:-$ROOT/Gys_Paa_Regneslottet.zip}"
EXTRACTED="$ROOT/extracted"
GAME_ROOT="$EXTRACTED/Gys På Regneslottet"
DOSBOX_ROOT="$GAME_ROOT/SYSTEM/DOSBOX"
RUNTIME="$ROOT/gys_runtime"
CONF="$RUNTIME/gys.conf"

if [[ "${GYS_DRY_RUN:-0}" == "1" ]]; then
  echo "ROOT=$ROOT"
  echo "ZIP=$ZIP"
  echo "GAME_ROOT=$GAME_ROOT"
  echo "DOSBOX_ROOT=$DOSBOX_ROOT"
  echo "RUNTIME=$RUNTIME"
fi

if [[ ! -d "$DOSBOX_ROOT/GAME/WINDOWS" || ! -f "$DOSBOX_ROOT/CDROM/CDROM.iso" ]]; then
  [[ -f "$ZIP" ]] || { echo "Kan ikke finde zip-filen: $ZIP" >&2; exit 1; }
  mkdir -p "$EXTRACTED"
  unzip -q -n "$ZIP" -d "$EXTRACTED"
fi

[[ -d "$DOSBOX_ROOT/GAME/WINDOWS" ]] || { echo "Windows 3.x game tree mangler: $DOSBOX_ROOT/GAME/WINDOWS" >&2; exit 1; }
[[ -f "$DOSBOX_ROOT/CDROM/CDROM.iso" ]] || { echo "CDROM.iso mangler: $DOSBOX_ROOT/CDROM/CDROM.iso" >&2; exit 1; }

# The bundled Windows 3.x Program Manager config references the Danish
# Network group (C:\WINDOWS\NETVÆRK.GRP). The game does not use it, and
# filename/encoding mismatches can trigger a "Fejl i gruppefilen" prompt.
# Remove that unused group reference instead of asking Windows to load it.
python3 - "$DOSBOX_ROOT/GAME/WINDOWS/PROGMAN.INI" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
raw = path.read_bytes()
newline = b'\r\n' if b'\r\n' in raw else b'\n'
text = raw.decode('latin-1')

# Drop the Program Manager Network group regardless of whether the Danish Æ
# byte is later displayed correctly, as mojibake, or as another single byte.
text = re.sub(r'^Group3=C:\\WINDOWS\\NETV.RK\.GRP\r?\n?', '', text, flags=re.MULTILINE)

# Also remove group id 3 from the saved display order.
def fix_order(match):
    nums = [n for n in match.group(1).split() if n != '3']
    return 'Order=' + (' ' + ' '.join(nums) if nums else '')
text = re.sub(r'^Order=\s*([0-9 ]*)\r?$', fix_order, text, flags=re.MULTILINE)

new = text.encode('latin-1')
if new != raw:
    path.write_bytes(new)
PY
rm -f "$DOSBOX_ROOT/GAME/WINDOWS/NETV’RK.GRP" "$DOSBOX_ROOT/GAME/WINDOWS/NETVÆRK.GRP"

mkdir -p "$RUNTIME"
ln -sfn "$DOSBOX_ROOT/GAME" "$RUNTIME/GAME"
ln -sfn "$DOSBOX_ROOT/CDROM" "$RUNTIME/CDROM"

# Windows 3.x multimedia titles can stutter if CPU cycles are too low or the
# audio buffer is too small. These defaults are smoother than the original
# bundled 20000 cycles, while still being easy to tune from Lutris/env.
CPU_CYCLES="${GYS_CPU_CYCLES:-40000}"
MIXER_BLOCKSIZE="${GYS_MIXER_BLOCKSIZE:-1024}"
MIXER_PREBUFFER="${GYS_MIXER_PREBUFFER:-80}"

cat > "$CONF" <<CONFEOF
[sdl]
fullscreen = false
windowresolution = 1024x768

[dosbox]
machine = svga_et4000
memsize = 16

[cpu]
core = auto
cputype = 486
cpu_cycles = ${CPU_CYCLES}

[dos]
xms = true
ems = false
umb = true

[mixer]
rate = 48000
blocksize = ${MIXER_BLOCKSIZE}
prebuffer = ${MIXER_PREBUFFER}

[sblaster]
sbtype = sb16
sbbase = 220
irq = 7
dma = 1
hdma = 5
mixer = true

[midi]
mididevice = none

[autoexec]
@echo off
mount c .\GAME
imgmount d .\CDROM\CDROM.iso -t iso
c:
cd windows
win c:\gilisoft\gys_cd\wnewaddd.exe /CFG:c:\gilisoft\gys_cd\wnewadd.ini /startdir:d:\dansk
exit
CONFEOF

if [[ "${GYS_DRY_RUN:-0}" == "1" ]]; then
  echo "CONF=$CONF"
  echo "DOSBOX_BIN=${GYS_DOSBOX_BIN:-auto}"
  exit 0
fi

cd "$RUNTIME"
if [[ -n "${GYS_DOSBOX_BIN:-}" ]]; then
  exec ${GYS_DOSBOX_BIN} -conf "$CONF" -noprimaryconf
elif command -v dosbox-staging >/dev/null 2>&1; then
  exec dosbox-staging -conf "$CONF" -noprimaryconf
elif command -v dosbox >/dev/null 2>&1; then
  exec dosbox -conf "$CONF" -noprimaryconf
elif command -v flatpak >/dev/null 2>&1 && flatpak info io.github.dosbox-staging >/dev/null 2>&1; then
  exec flatpak run io.github.dosbox-staging -conf "$CONF" -noprimaryconf
else
  echo "Kan ikke finde DOSBox. Installer dosbox-staging eller Flatpak app io.github.dosbox-staging." >&2
  exit 1
fi
