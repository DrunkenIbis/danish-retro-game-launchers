from pathlib import Path
import struct

data = Path("/home/test/lutris_game_scripts_Magnus_Myggen_Leg_og_Laer/cdrom/MMSYS.DLL").read_bytes()

ne_off = struct.unpack_from('<H', data, 0x3c)[0]
align_shift = struct.unpack_from('<H', data, ne_off + 0x32)[0]
seg_table_off = ne_off + struct.unpack_from('<H', data, ne_off + 0x22)[0]
n_segs = struct.unpack_from('<H', data, ne_off + 0x1c)[0]

segs = []
for i in range(n_segs):
    eo = seg_table_off + i * 8
    raw, vsz, flags, _ = struct.unpack_from('<HHHH', data, eo)
    foff = raw << align_shift
    stype = "DATA" if (flags & 1) else "CODE"
    segs.append((foff, vsz, flags, stype))
    print(f"Seg {i+1:2d}: foff=0x{foff:06x} vsz=0x{vsz:04x} {stype}")

print("\nOld patch targets (assumed seg=0x600):")
for off, ln in [(0x0002,5),(0x0160,6),(0x022f,5),(0x0355,3),(0x03b7,3)]:
    at = 0x600 + off
    print(f"  file 0x{at:04x}: {data[at:at+ln].hex()}")

target = bytes.fromhex('8cd89045')
print(f"\nSearch {target.hex()} (first hits):")
pos = 0
count = 0
while count < 10:
    idx = data.find(target, pos)
    if idx == -1:
        break
    print(f"  file 0x{idx:06x}: {data[max(0,idx-2):idx+10].hex()}")
    pos = idx + 1
    count += 1

print("\nCODE segs at IP=0x1068:")
for i, (foff, vsz, flags, stype) in enumerate(segs):
    if stype == "CODE":
        at = foff + 0x1068
        if at + 8 <= len(data):
            print(f"  Seg {i+1}: 0x{at:06x}: {data[at:at+8].hex()}")
