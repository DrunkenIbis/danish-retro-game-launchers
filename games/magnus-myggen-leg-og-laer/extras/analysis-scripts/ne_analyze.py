from pathlib import Path
import struct

# krnl386.exe16 NE header heap info
for p in [
    '/usr/lib/wine-wow64/wine/i386-windows/krnl386.exe16',
]:
    data = Path(p).read_bytes()
    ne_off = struct.unpack_from('<H', data, 0x3c)[0]
    if data[ne_off:ne_off+2] != b'NE':
        print(f"NOT NE: {p}")
        continue
    init_heap = struct.unpack_from('<H', data, ne_off + 0x0c)[0]
    init_stack = struct.unpack_from('<H', data, ne_off + 0x0e)[0]
    print(f"krnl386 init_heap=0x{init_heap:04x} ({init_heap}), init_stack=0x{init_stack:04x}")

# MAGNUS.EXE - er det NE (Win16) eller PE?
magnus = Path('/home/test/lutris_game_scripts_Magnus_Myggen_Leg_og_Laer/cdrom/MAGNUS.EXE')
data = magnus.read_bytes()
ne_off = struct.unpack_from('<H', data, 0x3c)[0]
sig = data[ne_off:ne_off+2]
print(f"\nMAGNUS.EXE: sig at 0x{ne_off:04x} = {sig}")
if sig == b'NE':
    init_heap = struct.unpack_from('<H', data, ne_off + 0x0c)[0]
    init_stack = struct.unpack_from('<H', data, ne_off + 0x0e)[0]
    n_segs = struct.unpack_from('<H', data, ne_off + 0x1c)[0]
    align_shift = struct.unpack_from('<H', data, ne_off + 0x32)[0]
    seg_table_off = ne_off + struct.unpack_from('<H', data, ne_off + 0x22)[0]
    print(f"  init_heap=0x{init_heap:04x} ({init_heap}), init_stack=0x{init_stack:04x}")
    print(f"  n_segs={n_segs}, align_shift={align_shift}")
    for i in range(min(n_segs, 6)):
        eo = seg_table_off + i * 8
        raw, vsz, flags, min_alloc = struct.unpack_from('<HHHH', data, eo)
        foff = raw << align_shift
        stype = "DATA" if (flags & 1) else "CODE"
        print(f"  Seg {i+1}: foff=0x{foff:06x} vsz=0x{vsz:04x} min_alloc=0x{min_alloc:04x} {stype}")
elif sig == b'PE':
    print("  MAGNUS.EXE is a PE (Win32) executable - winevdm wraps it as Win16")
else:
    # Small stub, look further
    print(f"  Unknown sig. Checking for NE at various offsets...")
    for test_off in [0x40, 0x50, 0x60, 0x80, 0x100]:
        s = data[test_off:test_off+2]
        if s == b'NE':
            print(f"  Found NE at 0x{test_off:04x}")
            heap = struct.unpack_from('<H', data, test_off + 0x0c)[0]
            print(f"  init_heap=0x{heap:04x}")
            break
