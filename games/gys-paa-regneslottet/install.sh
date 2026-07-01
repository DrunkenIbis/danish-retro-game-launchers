#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="gys-paa-regneslottet"
GAME_TITLE="Gys på Regneslottet"
ARCHIVE_NAME="Gys_Paa_Regneslottet.zip"
ARCHIVE_SHA256="0930e6961d89ac25638124812e0ad1637cb1cf97c0cc0229f937e5850461a0d2"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${GYS_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${GYS_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ARCHIVE_PATH="${GYS_ARCHIVE:-${GYS_ZIP:-$SOURCE_DIR/$ARCHIVE_NAME}}"
EXTRACTED_DIR="$RUNTIME_DIR/extracted"
GAME_ROOT="$EXTRACTED_DIR/Gys På Regneslottet"
DOSBOX_ROOT="$GAME_ROOT/SYSTEM/DOSBOX"
LOGDIR="$RUNTIME_DIR/logs"
LAUNCH_AFTER=1
MODE=""
ARCHIVE_INPUT=""

log() { printf '[%s] %s\n' "$GAME_TITLE" "$*"; }
fatal() { printf '[%s] FEJL: %s\n' "$GAME_TITLE" "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

usage() {
  cat <<EOF
Brug: $0 [valg]

Installer/importer for ${GAME_TITLE}.

Valg:
  --existing          brug zip-filen der allerede ligger i source-mappen
  --archive PATH      brug/kopiér et lokalt zip-arkiv på denne sti
  --no-launch         stop efter udpakning; start ikke spillet
  --launch            start spillet efter udpakning (default)
  -h, --help          vis hjælp

Miljøvariabler:
  RETRO_GAME_SOURCE_DIR  base-map til private spilfiler
  RETRO_GAME_RUNTIME_DIR base-map til runtime/udpakket data
  GYS_ARCHIVE/GYS_ZIP    konkret zip-arkivsti
  GYS_SOURCE_DIR         konkret source-map
  GYS_RUNTIME_DIR        konkret runtime-map

Der er ingen auto-download: brug en lovligt anskaffet kopi af ${ARCHIVE_NAME}.
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --existing) MODE="existing"; shift ;;
      --archive) [[ $# -gt 1 ]] || fatal "--archive kræver en sti"; MODE="archive"; ARCHIVE_INPUT="$2"; shift 2 ;;
      --no-launch) LAUNCH_AFTER=0; shift ;;
      --launch) LAUNCH_AFTER=1; shift ;;
      -h|--help) usage; exit 0 ;;
      *) fatal "Ukendt valg: $1" ;;
    esac
  done
}

choose_mode() {
  echo
  log "Arkiv-sti: $ARCHIVE_PATH"
  echo
  if [[ -f "$ARCHIVE_PATH" ]]; then
    echo "Der findes allerede et zip-arkiv. Hvad vil du gøre?"
    echo "  1) Brug eksisterende arkiv"
    echo "  2) Angiv/kopiér et lokalt zip-arkiv"
    echo "  q) Afbryd"
  else
    echo "Der findes intet zip-arkiv endnu. Hvad vil du gøre?"
    echo "  1) Angiv/kopiér et lokalt zip-arkiv"
    echo "  q) Afbryd"
  fi
  printf '> '
  read -r choice
  if [[ -f "$ARCHIVE_PATH" ]]; then
    case "$choice" in
      1) MODE="existing" ;;
      2) MODE="archive"; echo "Sti til zip-arkiv:"; printf '> '; read -r ARCHIVE_INPUT ;;
      q|Q) exit 0 ;;
      *) fatal "Ugyldigt valg" ;;
    esac
  else
    case "$choice" in
      1) MODE="archive"; echo "Sti til zip-arkiv:"; printf '> '; read -r ARCHIVE_INPUT ;;
      q|Q) exit 0 ;;
      *) fatal "Ugyldigt valg" ;;
    esac
  fi
}

verify_archive_checksum() {
  local actual
  actual="$(sha256sum "$ARCHIVE_PATH" | awk '{print $1}')"
  [[ "$actual" == "$ARCHIVE_SHA256" ]] || fatal "Forkert SHA256 for $ARCHIVE_PATH: $actual (forventede $ARCHIVE_SHA256)"
}

validate_archive() {
  need_cmd unzip
  need_cmd sha256sum
  [[ -f "$ARCHIVE_PATH" ]] || fatal "Zip-arkiv mangler: $ARCHIVE_PATH"
  verify_archive_checksum
  local list_file="$LOGDIR/archive-file-list.txt"
  unzip -Z1 "$ARCHIVE_PATH" >"$list_file"
  grep -Fxq 'Gys På Regneslottet/SYSTEM/DOSBOX/CDROM/CDROM.iso' "$list_file" || fatal "Arkivet indeholder ikke forventet CDROM.iso"
  grep -Fxq 'Gys På Regneslottet/SYSTEM/DOSBOX/GAME/WINDOWS/WIN.COM' "$list_file" || fatal "Arkivet indeholder ikke forventet Windows 3.x runtime"
  grep -Fxq 'Gys På Regneslottet/SYSTEM/DOSBOX/GAME/GILISOFT/GYS_CD/WNEWADDD.EXE' "$list_file" || fatal "Arkivet indeholder ikke forventet WNEWADDD.EXE launcher"
}

acquire_archive() {
  mkdir -p "$SOURCE_DIR" "$LOGDIR"
  case "$MODE" in
    existing)
      [[ -f "$ARCHIVE_PATH" ]] || fatal "Ingen eksisterende zip på: $ARCHIVE_PATH"
      ;;
    archive)
      [[ -n "$ARCHIVE_INPUT" ]] || fatal "Ingen lokal arkivsti angivet"
      [[ -f "$ARCHIVE_INPUT" ]] || fatal "Lokalt arkiv findes ikke: $ARCHIVE_INPUT"
      ARCHIVE_PATH="$SOURCE_DIR/$ARCHIVE_NAME"
      cp -f "$ARCHIVE_INPUT" "$ARCHIVE_PATH"
      ;;
    *) fatal "Intern fejl: ukendt mode '$MODE'" ;;
  esac
  validate_archive
}

extract_game() {
  log "Udpakker zip til privat runtime: $EXTRACTED_DIR"
  rm -rf "$EXTRACTED_DIR"
  mkdir -p "$EXTRACTED_DIR" "$LOGDIR"
  set +e
  unzip -q "$ARCHIVE_PATH" -d "$EXTRACTED_DIR" >"$LOGDIR/extract-zip.log" 2>&1
  local unzip_status=$?
  set -e

  [[ -d "$DOSBOX_ROOT/GAME/WINDOWS" ]] || fatal "Windows 3.x game tree mangler efter udpakning: $DOSBOX_ROOT/GAME/WINDOWS"
  [[ -f "$DOSBOX_ROOT/CDROM/CDROM.iso" ]] || fatal "CDROM.iso mangler efter udpakning: $DOSBOX_ROOT/CDROM/CDROM.iso"
  [[ -f "$DOSBOX_ROOT/GAME/GILISOFT/GYS_CD/WNEWADDD.EXE" ]] || fatal "WNEWADDD.EXE mangler efter udpakning"
  if [[ "$unzip_status" -ne 0 ]]; then
    log "unzip returnerede status $unzip_status, men alle krævede filer findes; fortsætter. Se $LOGDIR/extract-zip.log"
  fi
  log "Runtime klar: $RUNTIME_DIR"
}

main() {
  parse_args "$@"
  [[ -n "$MODE" ]] || choose_mode
  acquire_archive
  extract_game
  if [[ "$LAUNCH_AFTER" == 1 ]]; then
    log "Starter spillet via launch.sh"
    exec env GYS_ARCHIVE="$ARCHIVE_PATH" GYS_RUNTIME_DIR="$RUNTIME_DIR" "$HERE/launch.sh"
  else
    log "Færdig. Start senere med: cd '$HERE' && ./launch.sh"
  fi
}

main "$@"
