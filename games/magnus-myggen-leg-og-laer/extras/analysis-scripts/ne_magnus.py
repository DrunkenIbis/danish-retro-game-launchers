from pathlib import Path
import struct

# Find DATA segments in MAGNUS.EXE with their heap sizes
magnus = Path('/home/test/lutris_game_scripts_Magnus_Myggen_Leg_og_Laer/cdrom/MAGNUS.EXE')
data = magnus.read_bytes()
ne_off = 0x00b0  # from previous analysis
init_heap = struct.unpack_from('<H', data, ne_off + 0x0c)[0]
init_stack = struct.unpack_from('<H', data, ne_off + 0x0e)[0]
n_segs = struct.unpack_from('<H', data, ne_off + 0x1c)[0]
align_shift = struct.unpack_from('<H', data, ne_off + 0x32)[0]
seg_table_off = ne_off + struct.unpack_from('<H', data, ne_off + 0x22)[0]
print(f"MAGNUS.EXE: init_heap=0x{init_heap:04x} ({init_heap} bytes), init_stack=0x{init_stack:04x}")
print(f"total segments: {n_segs}, align_shift={align_shift}")

data_segs = []
for i in range(n_segs):
    eo = seg_table_off + i * 8
    raw, vsz, flags, min_alloc = struct.unpack_from('<HHHH', data, eo)
    foff = raw << align_shift
    stype = "DATA" if (flags & 1) else "CODE"
    has_reloc = bool(flags & 0x0100)
    if stype == "DATA":
        data_segs.append((i+1, foff, vsz, min_alloc, flags))
        print(f"  DATA Seg {i+1}: foff=0x{foff:06x} vsz=0x{vsz:04x} min_alloc=0x{min_alloc:04x} flags=0x{flags:04x}")

# The local heap is in the automatic data segment (DGROUP)
# DGROUP = segment with NODATA/MOVEABLE flags cleared AND is the automatic one
# In NE header: 0x1E = automatic data segment number
auto_ds = struct.unpack_from('<H', data, ne_off + 0x1e)[0]
print(f"\nAutomatic data segment (DGROUP): seg index {auto_ds}")
if 1 <= auto_ds <= n_segs:
    eo = seg_table_off + (auto_ds-1) * 8
    raw, vsz, flags, min_alloc = struct.unpack_from('<HHHH', data, eo)
    foff = raw << align_shift
    print(f"  DGROUP: foff=0x{foff:06x} vsz=0x{vsz:04x} min_alloc=0x{min_alloc:04x}")
    print(f"  Local heap fits in: 65536 - {min_alloc} = {65536 - min_alloc} bytes")
    print(f"  NE init_heap field = {init_heap} bytes declared")
