#!/usr/bin/env bash
# Opt-in SiMPLE community variant, never modify the official installed seed.
set -Eeuo pipefail
HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../scripts/common.sh"
ROOT="$(repo_root_from_game_dir "$HERE")"
BASE="$(retro_runtime_dir "$ROOT" battlefield-1942)"
SEED="${BF1942_SIMPLE_SEED:-$BASE/official161b/prefix-gameplay-verified}"
RUNTIME="${BF1942_SIMPLE_RUNTIME:-$BASE/simple161b}"
WINE="${BF1942_WINE:-$ROOT/local/runners/lutris-GE-Proton7-43-x86_64/bin/wine}"
ARCHIVE="${BF1942_SIMPLE_ARCHIVE:-$ROOT/local/cache/battlefield-1942/simple/bf1942-v1.61-retail-patched.zip}"
[[ -f "$SEED/system.reg" && -f "$SEED/drive_c/Program Files/EA GAMES/Battlefield 1942/BF1942.exe" ]] || { printf 'Missing installed seed: %s\n' "$SEED" >&2; exit 1; }
[[ "$SEED" == /* && "$RUNTIME" == /* && "$ARCHIVE" == /* ]] || { printf 'Paths must be absolute\n' >&2; exit 1; }
[[ -x "$WINE" && -x "$(dirname "$WINE")/wineserver" ]] || { printf 'Missing paired Wine runner\n' >&2; exit 1; }
[[ ! -e "$RUNTIME" && ! -L "$RUNTIME" ]] || { printf 'Preserving existing runtime\n' >&2; exit 1; }
# Bounded wait, not a kill: refuse to clone an active seed.
WINEPREFIX="$SEED" timeout 10 "$(dirname "$WINE")/wineserver" -w
python3 - "$SEED" "$RUNTIME" "$ARCHIVE" <<'PY'
import hashlib,json,os,shutil,stat,sys,zipfile
from pathlib import Path, PurePosixPath
seed,runtime,archive=map(Path,sys.argv[1:])
expected='2b062f53fde1d6efdbc8c9e37521050ff9102c018d79c13ca56f0f762c8f7c21'
if hashlib.sha256(archive.read_bytes()).hexdigest()!=expected:
 raise SystemExit('Unexpected SiMPLE archive hash; review a changed download separately')
for ancestor in [runtime,*runtime.parents]:
 if ancestor.is_symlink():raise SystemExit('Refusing symlinked output path')
if seed.resolve()==runtime.resolve() or seed.resolve() in runtime.resolve().parents or runtime.resolve() in seed.resolve().parents:
 raise SystemExit('Seed/runtime overlap')
rel=Path('drive_c/Program Files/EA GAMES/Battlefield 1942')
version=(seed/rel/'Mods/bf1942/init.con').read_text(errors='replace')
if 'game.setCustomGameVersion 1.61' not in version:raise SystemExit('Expected officially updated 1.61 seed')
allowed={'BF1942.exe','simple.txt','Mods/bf1942/contentCrc32.con','Mods/bf1942/init.con','Mods/bf1942/Mod.dll','Mods/XPack1/Mod.dll','Mods/XPack2/Mod.dll'}
with zipfile.ZipFile(archive) as z:
 if set(z.namelist())!=allowed or len(z.namelist())!=len(allowed):raise SystemExit('Unexpected archive members')
 if z.testzip() is not None:raise SystemExit('ZIP CRC error')
 for info in z.infolist():
  if stat.S_ISLNK(info.external_attr>>16):raise SystemExit('ZIP symlink refused')
 runtime.mkdir(parents=True,exist_ok=False)
 shutil.copytree(seed,runtime/'prefix',symlinks=True,copy_function=shutil.copy2)
 game=runtime/'prefix'/rel
 changes=[]
 for name in sorted(allowed):
  target=game/Path(PurePosixPath(name))
  for p in [target,*target.parents]:
   if p==game.parent:break
   if p.is_symlink():raise SystemExit('Refusing symlinked game target')
  old=hashlib.sha256(target.read_bytes()).hexdigest() if target.is_file() else None
  data=z.read(name);target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
  after=hashlib.sha256(target.read_bytes()).hexdigest()
  if after!=hashlib.sha256(data).hexdigest():raise SystemExit('Patch write verification failed')
  changes.append({'path':name,'before':old,'after':after})
 # Remove copied media mappings; Wine can rediscover empty optical devices.
 for p in (runtime/'prefix/dosdevices').iterdir():
  if p.name.endswith(':') and p.name not in ('c:','z:'):
   if not p.is_symlink():raise SystemExit('Unexpected real drive mapping')
   p.unlink()
 (runtime/'logs').mkdir()
 (runtime/'logs/simple-patch-manifest.json').write_text(json.dumps({'archive_sha256':expected,'seed':str(seed),'changes':changes,'gameplay_verified':False},indent=2)+'\n')
 print('Separate SiMPLE variant prepared:',runtime)
 print('Archive files applied:',len(changes))
 print('XPack DLLs are patch files only; expansion game data is NOT installed.')
PY
