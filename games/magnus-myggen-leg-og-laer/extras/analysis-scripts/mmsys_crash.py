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

# The crash backtrace:
# =>0  CS:034f IP:1068 (rep movsw)
#   1  CS:04bf IP:01ff
#   2  CS:052f IP:0116
#   etc
# Wine selectors for 16-bit segments are allocated sequentially starting at ~0x034f
# The actual segment index for a given selector depends on Wine's internal allocation
# Selector 0x034f = could be segment index (0x034f - 0x0007) / 8 + 1 (rough heuristic)
# More important: the crash instruction is rep movsw at IP=0x1068 in Seg that was CS=0x034f

# CS=0x034f is the FIRST code segment selector (seg 1, loaded at file 0x000600)
# Since seg1 file base = 0x000600 and crash IP = 0x1068:
crash_file_off = 0x000600 + 0x1068  # = 0x001668
print(f"Crash at file offset: 0x{crash_file_off:06x}")
print(f"Bytes: {data[crash_file_off:crash_file_off+10].hex()}")
# c4 bd = les di, [di+0xbd] -- load ES:DI pointer
# 90 = nop
# 01 06 57 9a = add [0x9a57], ax
# These aren't "rep movsw". Let's check more context:
print(f"Wider context: {data[crash_file_off-16:crash_file_off+32].hex()}")

# The crash says "rep movsw (%si), %es:(%di)" which is F3 A5
# Try to find F3 A5 near IP 0x1068 across all CODE segs
print("\nSearching for rep movsw (F3 A5) near IP offset 0x1068 +/- 0x40:")
repmovsw = bytes.fromhex('f3a5')
for i, (foff, vsz, flags, stype) in enumerate(segs):
    if stype == "CODE":
        window_start = foff + max(0, 0x1068 - 0x40)
        window_end   = foff + 0x1068 + 0x40
        window_data  = data[window_start:window_end]
        idx = window_data.find(repmovsw)
        if idx != -1:
            abs_off = window_start + idx
            local_off = abs_off - foff
            print(f"  Seg {i+1}: IP=0x{local_off:04x} file=0x{abs_off:06x}: {data[abs_off:abs_off+10].hex()}")

# Also search broadly across the whole DLL for F3 A5 occurrences
print("\nAll F3 A5 in DLL:")
pos = 0
count = 0
while count < 20:
    idx = data.find(repmovsw, pos)
    if idx == -1:
        break
    print(f"  file 0x{idx:06x}: IP in seg = ?  ctx: {data[max(0,idx-4):idx+8].hex()}")
    pos = idx + 1
    count += 1
