#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GAME_ID="gys-paa-regneslottet"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${GYS_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${GYS_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ARCHIVE="${GYS_ARCHIVE:-${GYS_ZIP:-$SOURCE_DIR/Gys_Paa_Regneslottet.zip}}"
SOURCE_BUNDLE_ROOT="$SOURCE_DIR/Gys_Paa_Regneslottet/Gys På Regneslottet"
EXTRACTED_DIR="$RUNTIME_DIR/extracted"
GAME_ROOT="$EXTRACTED_DIR/Gys På Regneslottet"
DOSBOX_ROOT="$GAME_ROOT/SYSTEM/DOSBOX"
GAME_TREE="$DOSBOX_ROOT/GAME"
CDROM_DIR="$DOSBOX_ROOT/CDROM"
RUNTIME_LINKS="$RUNTIME_DIR/dosbox-runtime"
CONF="$RUNTIME_DIR/gys-paa-regneslottet.conf"
LOGDIR="$RUNTIME_DIR/logs"
BUNDLED_CONF="${GYS_DOSBOX_CONF:-$SOURCE_BUNDLE_ROOT/SYSTEM/DOSBOX/dosbox.conf}"
WINDOWRES="${GYS_WINDOWRES:-640x480}"

mkdir -p "$RUNTIME_DIR" "$LOGDIR"

if [[ "${GYS_DRY_RUN:-0}" == "1" ]]; then
  printf 'HERE=%s\nREPO_ROOT=%s\nARCHIVE=%s\nRUNTIME_DIR=%s\nGAME_TREE=%s\nCDROM_DIR=%s\nBUNDLED_CONF=%s\nCONF=%s\nDOSBOX_BIN=%s\n' \
    "$HERE" "$REPO_ROOT" "$ARCHIVE" "$RUNTIME_DIR" "$GAME_TREE" "$CDROM_DIR" "$BUNDLED_CONF" "$CONF" "${GYS_DOSBOX_BIN:-auto}"
  exit 0
fi

if [[ ! -d "$GAME_TREE/WINDOWS" || ! -f "$CDROM_DIR/CDROM.iso" || ! -f "$GAME_TREE/GILISOFT/GYS_CD/WNEWADDD.EXE" ]]; then
  if [[ ! -f "$ARCHIVE" ]]; then
    echo "Zip-arkiv mangler: $ARCHIVE" >&2
    echo "Kør ./install.sh --archive /sti/til/Gys_Paa_Regneslottet.zip --no-launch, eller placér arkivet i local/sources/$GAME_ID/." >&2
    exit 1
  fi
  if ! command -v unzip >/dev/null 2>&1; then
    echo "unzip mangler; kan ikke udpakke $ARCHIVE" >&2
    exit 1
  fi
  rm -rf "$EXTRACTED_DIR"
  mkdir -p "$EXTRACTED_DIR"
  set +e
  unzip -q "$ARCHIVE" -d "$EXTRACTED_DIR" >"$LOGDIR/extract-zip.log" 2>&1
  unzip_status=$?
  set -e
fi

[[ -d "$GAME_TREE/WINDOWS" ]] || { echo "Windows 3.x game tree mangler: $GAME_TREE/WINDOWS" >&2; exit 1; }
[[ -f "$CDROM_DIR/CDROM.iso" ]] || { echo "CDROM.iso mangler: $CDROM_DIR/CDROM.iso" >&2; exit 1; }
[[ -f "$GAME_TREE/GILISOFT/GYS_CD/WNEWADDD.EXE" ]] || { echo "WNEWADDD.EXE mangler: $GAME_TREE/GILISOFT/GYS_CD/WNEWADDD.EXE" >&2; exit 1; }
if [[ ! -f "$BUNDLED_CONF" ]]; then
  BUNDLED_CONF="$DOSBOX_ROOT/dosbox.conf"
fi
[[ -f "$BUNDLED_CONF" ]] || { echo "Bundled DOSBox config mangler: $BUNDLED_CONF" >&2; exit 1; }
if [[ "${unzip_status:-0}" -ne 0 ]]; then
  echo "unzip returnerede status $unzip_status, men alle krævede filer findes; fortsætter. Se $LOGDIR/extract-zip.log" >&2
fi

# The bundled Windows 3.x Program Manager config references the Danish
# Network group (C:\WINDOWS\NETVÆRK.GRP). The game does not use it, and
# filename/encoding mismatches can trigger a "Fejl i gruppefilen" prompt.
# Remove that unused group reference instead of asking Windows to load it.
python3 - "$GAME_TREE/WINDOWS/PROGMAN.INI" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
raw = path.read_bytes()
text = raw.decode('latin-1')
text = re.sub(r'^Group3=C:\\WINDOWS\\NETV.RK\.GRP\r?\n?', '', text, flags=re.MULTILINE)

def fix_order(match):
    nums = [n for n in match.group(1).split() if n != '3']
    return 'Order=' + (' ' + ' '.join(nums) if nums else '')

text = re.sub(r'^Order=\s*([0-9 ]*)\r?$', fix_order, text, flags=re.MULTILINE)
new = text.encode('latin-1')
if new != raw:
    path.write_bytes(new)
PY
rm -f "$GAME_TREE/WINDOWS/NETV’RK.GRP" "$GAME_TREE/WINDOWS/NETVÆRK.GRP"

# Keep the bundled Windows 3.1 install on the period-correct 640x480/256-colour
# Super VGA driver. The title's WinG startup check can otherwise show "your
# windows graphics driver can't display enough colors" even though DOSBox has
# entered SVGA mode 2Eh. The bundled install marks this profile with value 2;
# value 1 still triggers WinG's "encountered a problem" retry/cancel dialog.
# Deleting the profile on every launch forces WinG to benchmark and can crash
# DOSBox-Staging, so keep the bundled-good profile deterministic instead.
python3 - "$GAME_TREE/WINDOWS/SYSTEM.INI" "$GAME_TREE/WINDOWS/WIN.INI" "$GAME_TREE/GILISOFT/GYS_CD/WNEWADD.INI" <<'PY'
from pathlib import Path
import re
import sys

system_ini, win_ini, game_ini = map(Path, sys.argv[1:])

text = system_ini.read_bytes().decode('latin-1')
replacements = {
    r'(?im)^display\.drv=.*$': 'display.drv=SVGA256.DRV',
    r'(?im)^386grabber=.*$': '386grabber=VGADIB.3GR',
    r'(?im)^display=VDDSVGA\.386$': 'display=VDDSVGA.386',
    r'(?im)^display\.drv=Super VGA.*$': 'display.drv=Super VGA (640x480, 256 farver)',
    r'(?im)^resolution=.*$': 'resolution=1',
    r'(?im)^svgamode=.*$': 'svgamode=46',
    r'(?im)^ChipSet=.*$': 'ChipSet=Tseng ET4000',
}
for pattern, repl in replacements.items():
    text = re.sub(pattern, repl, text)
text = re.sub(
    r'(?ims)(\[boot\.description\].*?)^display\.drv=.*?$',
    lambda match: match.group(1) + 'display.drv=Super VGA (640x480, 256 farver)',
    text,
)
if re.search(r'(?im)^\[sndblst\.drv\]\s*$', text):
    text = re.sub(r'(?im)^port=.*$', 'port=220', text)
    text = re.sub(r'(?im)^int=.*$', 'int=7', text)
    if not re.search(r'(?im)^dmachannel=', text):
        text = re.sub(r'(?im)^(\[sndblst\.drv\]\s*)', r'\1dmachannel=1\r\n', text)
system_ini.write_bytes(text.encode('latin-1'))

text = win_ini.read_bytes().decode('latin-1')
wing_entry = 'SVGA256.DRV640x480x8(0,0)v3.11.0.300-3A99-1.0.0.37=2'
text = re.sub(r'(?ims)^\[WinG\]\s*.*?(?=^\[[^\]]+\]|\Z)', '', text).rstrip()
text += '\r\n\r\n[WinG]\r\n' + wing_entry + '\r\n'
win_ini.write_bytes(text.encode('latin-1'))

text = game_ini.read_bytes().decode('latin-1')
text = re.sub(r'(?im)^StartMaximized\s*=.*$', 'StartMaximized=No', text)
game_ini.write_bytes(text.encode('latin-1'))
PY

rm -rf "$RUNTIME_LINKS"
mkdir -p "$RUNTIME_LINKS"
ln -sfn "$GAME_TREE" "$RUNTIME_LINKS/GAME"
ln -sfn "$CDROM_DIR" "$RUNTIME_LINKS/CDROM"
# The bundled DOSBox config is for DOSBox SVN-Daum and produces hundreds of
# invalid/deprecated-option warnings on DOSBox-Staging 0.82.x. Generate a small
# Staging-native config that preserves the title's proven SVGA/Sound Blaster
# profile without carrying forward legacy SVN-Daum-only keys.
python3 - "$BUNDLED_CONF" "$CONF" <<'PY'
from pathlib import Path
import os
import sys

src = Path(sys.argv[1])
dst = Path(sys.argv[2])
src.read_text(encoding='latin-1')  # fail early if the expected bundled config is missing/unreadable

windowres = os.environ.get('GYS_WINDOWRES', '640x480')
# Win3.11 paging exercises the normal-core fallback even with core=auto.
# 50000 saturated a host core; 15000 leaves scheduling headroom for audio.
core = os.environ.get('GYS_CPU_CORE', 'normal')
cycles = os.environ.get('GYS_CPU_CYCLES', '15000')
blocksize = os.environ.get('GYS_MIXER_BLOCKSIZE', '2048')
prebuffer = os.environ.get('GYS_MIXER_PREBUFFER', '80')

text = f"""# Generated by games/gys-paa-regneslottet/launch.sh.
# Staging-native clean config derived from the game-bundled DOSBox-SVN/Daum profile.

[sdl]
output = opengl
fullscreen = false
fullresolution = desktop
windowresolution = {windowres}
priority = auto auto
mute_when_inactive = false
pause_when_inactive = false

[dosbox]
machine = svga_et4000
memsize = 16
vmemsize = auto

[render]
glshader = crt-auto
aspect = auto
integer_scaling = auto
viewport = fit

[cpu]
core = {core}
cputype = 486
cpu_cycles = {cycles}
cpu_cycles_protected = auto
cpu_throttle = false

[voodoo]
voodoo = false

[mixer]
nosound = false
rate = 44100
blocksize = {blocksize}
prebuffer = {prebuffer}
negotiate = true
compressor = true
crossfeed = off
reverb = off
chorus = off

[midi]
mididevice = none

[sblaster]
sbtype = sb2
sbbase = 220
irq = 7
dma = 1
hdma = 5
sbmixer = true
sbwarmup = 100
sb_filter = modern
sb_filter_always_on = false
oplmode = auto
opl_fadeout = off
opl_remove_dc_bias = false
opl_filter = auto
cms = auto
cms_filter = on

[gus]
gus = false

[ethernet]
ne2000 = false

[autoexec]
# Runtime wrapper block generated from the bundled game config.
@echo off
MOUNT C ./GAME
IMGMOUNT D ./CDROM/CDROM.iso -t iso
C:
CD WINDOWS
WIN C:\\GILISOFT\\GYS_CD\\WNEWADDD.EXE /CFG:C:\\GILISOFT\\GYS_CD\\WNEWADD.INI /startdir:D:\\DANSK
EXIT
"""

dst.write_text(text, encoding='latin-1', newline='')
PY

cd "$RUNTIME_LINKS"
export SDL_AUDIODRIVER="${GYS_SDL_AUDIODRIVER:-pulse}"
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
