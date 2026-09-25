#!/usr/bin/env bash
# Optional third-party SiMPLE 1.21 experiment, NOT an official EA patch.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
BASE="$(retro_runtime_dir "$ROOT" battlefield-vietnam)"
SOURCE="$BASE/patch121-ge7"
DEST="$BASE/simple121-ge7"
ZIP="$(retro_source_dir "$ROOT" battlefield-vietnam)/patches/bfvietnam-v1.21-patched.zip"
SERVER="$ROOT/local/runners/lutris-GE-Proton7-43-x86_64/bin/wineserver"
[[ -x "$SERVER" && -f "$ZIP" && -f "$SOURCE/prefix/system.reg" ]]
[[ ! -e "$DEST" && ! -L "$DEST" && ! -L "$SOURCE" && ! -L "$SOURCE/prefix" ]]
exec 9>"$SOURCE/.lock"
flock -n 9
WINEPREFIX="$SOURCE/prefix" timeout 20 "$SERVER" -w 9>&-
python3 - "$SOURCE/prefix" "$ZIP" <<'PY'
import sys,zipfile
from pathlib import Path
p=Path(sys.argv[1]); z=zipfile.ZipFile(sys.argv[2])
assert '"INSTALLEDVERSION"="1.21.001"' in (p/'system.reg').read_text(errors='replace'), 'Expected official 1.21'
assert not (p/'drive_c').is_symlink()
assert z.testzip() is None
allowed={'BfVietnam.exe','Mods/','Mods/BfVietnam/','Mods/BfVietnam/init.con','Mods/BfVietnam/LevelCheck.con','Mods/BfVietnam/Mod.dll','simple.txt'}
assert set(z.namelist())==allowed, 'Unexpected archive contents'
PY
mkdir "$DEST"
cp -a --reflink=auto "$SOURCE/prefix" "$DEST/prefix"
python3 - "$DEST" "$ZIP" <<'PY'
from pathlib import Path
import zipfile,sys,hashlib,json
root=Path(sys.argv[1]); prefix=root/'prefix'
game=prefix/'drive_c/Program Files/EA GAMES/Battlefield Vietnam'
z=zipfile.ZipFile(sys.argv[2]); records=[]
for name in z.namelist():
 if name.endswith('/') or name=='simple.txt': continue
 target=game
 for part in name.split('/'):
  matches=[p for p in target.iterdir() if p.name.lower()==part.lower()]
  assert len(matches)==1, 'Missing/ambiguous original '+name
  target=matches[0]
  assert not target.is_symlink(), 'Refusing symlink '+str(target)
 assert target.is_file()
 before=hashlib.sha256(target.read_bytes()).hexdigest()
 data=z.read(name); target.write_bytes(data)
 records.append({'file':str(target.relative_to(game)),'original_sha256':before,'patched_sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
(root/'simple-manifest.json').write_text(json.dumps({'source':'https://team-simple.org/download/bfvietnam-v1.21-patched.zip','zip_sha256':hashlib.sha256(Path(sys.argv[2]).read_bytes()).hexdigest(),'files':records},indent=2)+'\n')
print('SiMPLE applied in separate runtime:',root)
PY
