#!/usr/bin/env bash
# Private cooked-data backup; no claim to preserve protection/subchannel data.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
LABEL="${1:?Usage: backup-disc.sh BFV_1|BFV_2|BFV_3}"
case "$LABEL" in BFV_1|BFV_2|BFV_3) ;; *) printf 'Wrong disc label\n' >&2; exit 1;; esac
DEVICE="${BFV_DEVICE:-/dev/sr0}"
DEST="$(retro_source_dir "$ROOT" battlefield-vietnam)/backups"
RESCUE="${BFV_DDRESCUE:-$(command -v ddrescue || true)}"
if [[ -z "$RESCUE" && -x "$ROOT/local/cache/global-operations/ddrescue/ddrescue-1.30/ddrescue" ]]; then
  RESCUE="$ROOT/local/cache/global-operations/ddrescue/ddrescue-1.30/ddrescue"
fi
[[ -x "$RESCUE" ]] || { printf 'GNU ddrescue missing; set BFV_DDRESCUE. No packages installed automatically.\n' >&2; exit 1; }
command -v cd-info >/dev/null
# Refuse incorrect/non-optical devices before creating a backup.
python3 - "$DEVICE" "$LABEL" <<'PY'
import os, stat, sys
from pathlib import Path
p=Path(sys.argv[1]).resolve()
if not stat.S_ISBLK(p.stat().st_mode): sys.exit('Not a block device')
if (Path('/sys/class/block')/p.name/'device/type').read_text().strip()!='5': sys.exit('Not an optical drive')
f=os.open(p,os.O_RDONLY)
try:
 b=os.pread(f,2048,32768)
 if b[:7]!=b'\x01CD001\x01' or b[40:72].decode('ascii').strip()!=sys.argv[2]: sys.exit('Wrong medium')
finally: os.close(f)
PY
mkdir -p "$DEST"
exec 9>"$DEST/.backup.lock"
flock -n 9
[[ ! -e "$DEST/$LABEL.iso" && ! -e "$DEST/$LABEL.map" ]] || { printf 'Existing backup preserved; inspect its map before a separate recovery attempt.\n' >&2; exit 1; }
timeout 45 cd-info --no-cddb --no-analyze --cdrom-device="$DEVICE" >"$DEST/$LABEL.toc.txt"
SIZE="$(python3 - "$DEST/$LABEL.toc.txt" <<'PY'
import re,sys
from pathlib import Path
s=Path(sys.argv[1]).read_text()
if 'CD-DATA (Mode 1)' not in s or not re.search(r'CD-ROM Track List \(1 - 1\)',s): sys.exit('Not verified single-track Mode 1: choose a format preserving all tracks instead')
m=re.search(r'^170:\s+\S+\s+(\d+)\s+leadout',s,re.M)
if not m:sys.exit('Missing leadout sector count')
print(int(m.group(1))*2048)
PY
)"
printf 'Source=%s Label=%s Expected bytes=%s\n' "$DEVICE" "$LABEL" "$SIZE" | tee "$DEST/$LABEL.source.txt"
rc=0
# Bounded first pass: retain a rescue map; do not conceal unreadable sectors.
"$RESCUE" -b 2048 -s "$SIZE" -n -N -T 60s "$DEVICE" "$DEST/$LABEL.iso" "$DEST/$LABEL.map" >"$DEST/$LABEL.ddrescue.log" 2>&1 || rc=$?
python3 - "$DEST" "$LABEL" "$SIZE" "$rc" <<'PY'
from pathlib import Path
import hashlib,json,sys
root=Path(sys.argv[1]); label=sys.argv[2]; expected=int(sys.argv[3]); rc=int(sys.argv[4])
image=root/(label+'.iso'); mapfile=root/(label+'.map')
counts={}; regions=[]
for line in mapfile.read_text().splitlines():
 fields=line.split()
 if not fields or fields[0].startswith('#') or len(fields)!=3:continue
 try: start=int(fields[0],0); size=int(fields[1],0)
 except ValueError:continue
 status=fields[2];counts[status]=counts.get(status,0)+size;regions.append((start,size,status))
regions.sort();end=0;contiguous=True
for start,size,status in regions:
 if start!=end: contiguous=False
 end=start+size
with image.open('rb') as f: digest=hashlib.file_digest(f,'sha256').hexdigest()
complete=rc==0 and contiguous and end==expected and counts.get('+',0)==expected and image.stat().st_size==expected
report={'label':label,'format':'ISO9660 cooked Mode 1, 2048 bytes/sector','expected_bytes':expected,'actual_bytes':image.stat().st_size,'sha256':digest,'ddrescue_exit':rc,'map_bytes_by_status':counts,'all_data_sectors_read':complete,'raw_subchannel_or_copy_protection_preserved':False}
(root/(label+'.report.json')).write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
if not complete:sys.exit('INCOMPLETE rescue copy: inspect map/log; never claim complete backup')
PY
