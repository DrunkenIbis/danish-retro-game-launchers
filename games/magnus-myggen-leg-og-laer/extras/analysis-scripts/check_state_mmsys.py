import sys
from pathlib import Path

p = Path.home() / ".local/share/magnus-myggen-leg-og-laer/wineprefix32/drive_c/MAGNUS/MMSYS.DLL"
if not p.exists():
    print("MANGLER")
    sys.exit(0)

data = p.read_bytes()
seg = 0x600
pats = {
    0x0002: bytes.fromhex('31c0ca0400'),
    0x0160: bytes.fromhex('b80100ca0200'),
    0x022f: bytes.fromhex('31c0ca0200'),
    0x0355: bytes.fromhex('31c0cb'),
    0x03b7: bytes.fromhex('31c0cb'),
}
for off, exp in pats.items():
    at = seg + off
    act = data[at:at+len(exp)]
    s = 'PATCHED' if act == exp else f'ORIG {act.hex()}'
    print(f"  0x{at:04x}: {s}")
