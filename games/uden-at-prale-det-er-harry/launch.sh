#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
GAME_ID="uden-at-prale-det-er-harry"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${HARRY_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${HARRY_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ISO_PATH="${HARRY_ISO:-$SOURCE_DIR/uden-at-prale-det-er-harry.iso}"
CDROM_DIR="${HARRY_CDROM_DIR:-$RUNTIME_DIR/cdrom}"
WINEPREFIX="${HARRY_WINEPREFIX:-$RUNTIME_DIR/wineprefix}"
export WINEPREFIX
export WINEDEBUG="${WINEDEBUG:--all}"
DESKTOP_SIZE="${HARRY_DESKTOP_SIZE:-800x600}"
MODE="${1:-${HARRY_MODE:-game}}"
GAME_DIR="$WINEPREFIX/drive_c/Harry"
LOCK_FILE="$RUNTIME_DIR/.launch.lock"

log() { printf '[Harry] %s\n' "$*"; }
fatal() { printf '[Harry] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

resolve_wine() {
  if [[ -n "${HARRY_WINE:-}" ]]; then
    WINE_BIN="$HARRY_WINE"
  elif command -v wine32 >/dev/null 2>&1; then
    WINE_BIN="$(command -v wine32)"
  elif command -v wine >/dev/null 2>&1; then
    WINE_BIN="$(command -v wine)"
  else
    fatal "Mangler wine32/wine"
  fi
  [[ -x "$WINE_BIN" ]] || fatal "Wine er ikke eksekverbar: $WINE_BIN"

  if [[ -n "${HARRY_WINESERVER:-}" ]]; then
    WINESERVER_BIN="$HARRY_WINESERVER"
  elif command -v wineserver >/dev/null 2>&1; then
    WINESERVER_BIN="$(command -v wineserver)"
  else
    WINESERVER_BIN="$WINE_BIN"
  fi
}

extract_cdrom_if_needed() {
  if [[ -f "$CDROM_DIR/CDmenu.exe" && -f "$CDROM_DIR/setup.exe" ]]; then
    return 0
  fi
  [[ -f "$ISO_PATH" ]] || fatal "ISO mangler: $ISO_PATH. Kør ./install.sh --download eller ./install.sh --existing først."
  need_cmd 7z
  log "Udpakker ISO til runtime CD-ROM: $CDROM_DIR"
  rm -rf "$CDROM_DIR"
  mkdir -p "$CDROM_DIR" "$RUNTIME_DIR/logs"
  7z x -y -o"$CDROM_DIR" "$ISO_PATH" >"$RUNTIME_DIR/logs/extract.log"
  [[ -f "$CDROM_DIR/CDmenu.exe" ]] || fatal "CDmenu.exe mangler efter udpakning"
  [[ -f "$CDROM_DIR/setup.exe" ]] || fatal "setup.exe mangler efter udpakning"
}

init_prefix_if_needed() {
  if [[ -f "$WINEPREFIX/system.reg" ]]; then
    return 0
  fi
  log "Initialiserer Wine-prefix: $WINEPREFIX"
  mkdir -p "$(dirname "$WINEPREFIX")"
  export WINEARCH="${HARRY_WINEARCH:-win32}"
  timeout "${HARRY_WINEBOOT_TIMEOUT:-120}" "$WINE_BIN" wineboot -u >/dev/null 2>&1 || true
}

map_cd_drive() {
  mkdir -p "$WINEPREFIX/dosdevices"
  ln -sfn "$CDROM_DIR" "$WINEPREFIX/dosdevices/d:"
  rm -f "$WINEPREFIX/dosdevices/d::"
  printf 'HARRY\n' > "$CDROM_DIR/.windows-label"

  # Vigtig detalje for dette spil: CD-checken virker med D: som en almindelig
  # Wine drive med label HARRY. Registry cdrom-markering kan få vol d: til at
  # larme eller få spillet til stadig at afvise CD'en.
  "$WINE_BIN" reg delete 'HKCU\Software\Wine\Drives' /v 'd:' /f >/dev/null 2>&1 || true
  "$WINE_BIN" reg add 'HKCU\Software\Wine' /v Version /t REG_SZ /d win98 /f >/dev/null 2>&1 || true
}

seed_original_iv32_backup_if_needed() {
  local backup_movies_dir="$GAME_DIR/movies.original-iv32-backup"
  local backup_source="${HARRY_IV32_BACKUP_SOURCE:-}"
  local source_files=()

  [[ -d "$backup_movies_dir" ]] && return 0
  [[ -n "$backup_source" ]] || return 0
  [[ -d "$backup_source" ]] || return 0

  shopt -s nullglob
  source_files=("$backup_source"/*.avi)
  shopt -u nullglob

  (( ${#source_files[@]} > 0 )) || return 0

  log "Seeder originale IV32-AVI-filer fra $backup_source"
  mkdir -p "$backup_movies_dir"
  cp -av "${source_files[@]}" "$backup_movies_dir/" >/dev/null
}

movie_requires_400x216() {
  case "$1" in
    intro_scene_new_1.avi|cutscene_1.avi|cutscene_2.avi|cutscene_3.avi|outro.avi) return 0 ;;
    *) return 1 ;;
  esac
}

movie_is_compatible() {
  local movie="$1" codec_status dims_status base
  base="$(basename "$movie")"
  codec_status="$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of csv=p=0 "$movie" 2>/dev/null || true)"
  dims_status="$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$movie" 2>/dev/null || true)"
  [[ "$codec_status" == "msvideo1" ]] || return 1
  if movie_requires_400x216 "$base" && [[ "$dims_status" != "400x216" ]]; then
    return 1
  fi
  return 0
}

transcode_movies_to_msvideo1_if_needed() {
  local backup_movies_dir="$GAME_DIR/movies.original-iv32-backup"
  local movies_dir="$GAME_DIR/movies"
  local -a source_dirs=()
  local -a source_files=()
  local -a ffmpeg_video_args=()
  local -A seen=()
  local src dest needs_transcode=0 tmp base

  seed_original_iv32_backup_if_needed

  mkdir -p "$movies_dir"

  [[ -d "$backup_movies_dir" ]] && source_dirs+=("$backup_movies_dir")
  [[ -d "$movies_dir" ]] && source_dirs+=("$movies_dir")
  (( ${#source_dirs[@]} > 0 )) || return 0

  need_cmd ffmpeg
  need_cmd ffprobe

  for src_dir in "${source_dirs[@]}"; do
    shopt -s nullglob
    for src in "$src_dir"/*.avi; do
      base="$(basename "$src")"
      [[ -n "${seen[$base]:-}" ]] && continue
      seen[$base]=1
      source_files+=("$src")
    done
    shopt -u nullglob
  done

  (( ${#source_files[@]} > 0 )) || return 0

  for src in "${source_files[@]}"; do
    dest="$movies_dir/$(basename "$src")"
    if [[ ! -f "$dest" ]] || ! movie_is_compatible "$dest"; then
      needs_transcode=1
      break
    fi
  done

  [[ "$needs_transcode" == 1 ]] || return 0

  for src in "${source_files[@]}"; do
    dest="$movies_dir/$(basename "$src")"
    if [[ -f "$dest" ]] && movie_is_compatible "$dest"; then
      continue
    fi
    log "Transcoder AVI til Microsoft Video 1: $(basename "$src")"
    ffmpeg_video_args=(-c:v msvideo1)
    if movie_requires_400x216 "$(basename "$dest")"; then
      # Director/Wine MCI reports intro_scene_new_1.avi as unsupported when the
      # MSVC transcode preserves the original 400x224 frame. Normalize this
      # cutscene family to the same 400x216 geometry as the ticket/hello/race
      # clips that Director accepts.
      ffmpeg_video_args=(-vf scale=400:216 -c:v msvideo1)
    fi
    if [[ "$src" == "$dest" ]]; then
      tmp="$dest.transcode.$$.avi"
      ffmpeg -y -hide_banner -loglevel error -i "$src" "${ffmpeg_video_args[@]}" -c:a pcm_s16le "$tmp"
      mv -f "$tmp" "$dest"
    else
      ffmpeg -y -hide_banner -loglevel error -i "$src" "${ffmpeg_video_args[@]}" -c:a pcm_s16le "$dest"
    fi
  done
}

install_game_if_needed() {
  if [[ -x "$GAME_DIR/harry.exe" ]]; then
    return 0
  fi
  if [[ "${HARRY_AUTO_INSTALL:-1}" != "1" ]]; then
    fatal "Installeret Harry mangler: $GAME_DIR/harry.exe. Kør HARRY_MODE=setup ./launch.sh eller slå HARRY_AUTO_INSTALL=1 til."
  fi
  log "Installerer Harry stille fra Inno Setup"
  cd "$CDROM_DIR"
  "$WINE_BIN" 'D:\setup.exe' /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /DIR='C:\Harry'
  [[ -x "$GAME_DIR/harry.exe" ]] || fatal "Installationen blev færdig, men $GAME_DIR/harry.exe mangler"
}

launch_wine_desktop() {
  local target="$1" cwd="$2"
  cd "$cwd"
  exec "$WINE_BIN" explorer "/desktop=Harry,$DESKTOP_SIZE" "$target"
}

launch_wine_direct() {
  local target="$1" cwd="$2"
  cd "$cwd"
  exec "$WINE_BIN" "$target"
}

main() {
  mkdir -p "$RUNTIME_DIR"
  resolve_wine

  case "$MODE" in
    kill)
      if [[ "$WINESERVER_BIN" == "$WINE_BIN" ]]; then
        exec "$WINE_BIN" wineserver -k
      else
        exec "$WINESERVER_BIN" -k
      fi
      ;;
  esac

  (
    flock 9
    extract_cdrom_if_needed
    init_prefix_if_needed
    map_cd_drive
    case "$MODE" in
      setup|install|cdmenu|menu) : ;;
      prepare|game|installed) install_game_if_needed ;;
      *) fatal "Ukendt HARRY_MODE=$MODE; brug game, cdmenu, setup, prepare eller kill" ;;
    esac
    if [[ "$MODE" == "game" || "$MODE" == "installed" || "$MODE" == "prepare" ]]; then
      transcode_movies_to_msvideo1_if_needed
    fi
  ) 9>"$LOCK_FILE"

  case "$MODE" in
    prepare)
      log "Runtime klar: $RUNTIME_DIR"
      exit 0
      ;;
    game|installed) launch_wine_desktop 'C:\Harry\harry.exe' "$GAME_DIR" ;;
    cdmenu|menu) launch_wine_desktop 'D:\CDmenu.exe' "$CDROM_DIR" ;;
    setup|install) launch_wine_desktop 'D:\setup.exe' "$CDROM_DIR" ;;
  esac
}

main "$@"
