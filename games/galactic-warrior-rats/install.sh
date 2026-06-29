#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

GAME_ID="galactic-warrior-rats"
GAME_TITLE="Galactic Warrior Rats"
ARCHIVE_URL="https://archive.org/download/003318-GalacticWarriorRats/003318_galactic_warrior_rats.7z"
ARCHIVE_NAME="003318_galactic_warrior_rats.7z"
ARCHIVE_SHA256="44e67d11a9b7cd76f5553b3cbe6d618f64108cee05b0e26114632ad1e11ce4d1"

SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
RUNTIME_BASE="${RETRO_GAME_RUNTIME_DIR:-$REPO_ROOT/local/runtime}"
SOURCE_DIR="${GWR_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
RUNTIME_DIR="${GWR_RUNTIME_DIR:-$RUNTIME_BASE/$GAME_ID}"
ARCHIVE_PATH="${GWR_ARCHIVE:-$SOURCE_DIR/$ARCHIVE_NAME}"
EXTRACT_DIR="$SOURCE_DIR/archive-extracted"
DISK_IMG="$EXTRACT_DIR/003318_galactic_warrior_rats/disk1.img"
GAME_DIR="$RUNTIME_DIR/game"
LOGDIR="$RUNTIME_DIR/logs"
LAUNCH_AFTER=1
MODE=""

log() { printf '[%s] %s\n' "$GAME_TITLE" "$*"; }
fatal() { printf '[%s] FEJL: %s\n' "$GAME_TITLE" "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

usage() {
  cat <<EOF
Brug: $0 [valg]

Installer/importer for ${GAME_TITLE}.

Valg:
  --existing          brug 7z-arkivet der allerede ligger i source-mappen
  --download          download 7z-arkivet fra archive.org reference-linket
  --archive PATH      brug/kopiér et lokalt 7z-arkiv på denne sti
  --no-launch         stop efter udpakning; start ikke spillet
  --launch            start spillet efter udpakning (default)
  -h, --help          vis hjælp

Miljøvariabler:
  RETRO_GAME_SOURCE_DIR  base-map til private spilfiler
  RETRO_GAME_RUNTIME_DIR base-map til runtime/udpakket data
  GWR_ARCHIVE            konkret 7z-arkivsti
  GWR_SOURCE_DIR         konkret source-map
  GWR_RUNTIME_DIR        konkret runtime-map
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --existing) MODE="existing"; shift ;;
      --download) MODE="download"; shift ;;
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
    echo "Der findes allerede et 7z-arkiv. Hvad vil du gøre?"
    echo "  1) Brug eksisterende arkiv"
    echo "  2) Download igen fra reference-linket og overskriv"
    echo "  3) Angiv et lokalt 7z-arkiv"
    echo "  q) Afbryd"
    printf '> '
    read -r choice
    case "$choice" in
      1) MODE="existing" ;;
      2) MODE="download" ;;
      3) MODE="archive"; echo "Sti til 7z-arkiv:"; printf '> '; read -r ARCHIVE_INPUT ;;
      q|Q) exit 0 ;;
      *) fatal "Ugyldigt valg" ;;
    esac
  else
    echo "Der findes intet 7z-arkiv endnu. Hvad vil du gøre?"
    echo "  1) Download fra reference-linket"
    echo "  2) Angiv et lokalt 7z-arkiv"
    echo "  q) Afbryd"
    printf '> '
    read -r choice
    case "$choice" in
      1) MODE="download" ;;
      2) MODE="archive"; echo "Sti til 7z-arkiv:"; printf '> '; read -r ARCHIVE_INPUT ;;
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
  need_cmd 7z
  [[ -f "$ARCHIVE_PATH" ]] || fatal "7z-arkiv mangler: $ARCHIVE_PATH"
  verify_archive_checksum
  log "Validerer 7z-arkivet og floppy-image..."
  7z l "$ARCHIVE_PATH" | grep -Fq '003318_galactic_warrior_rats/disk1.img' || fatal "Arkivet indeholder ikke forventet disk1.img"
}

acquire_archive() {
  mkdir -p "$SOURCE_DIR"
  case "$MODE" in
    existing)
      [[ -f "$ARCHIVE_PATH" ]] || fatal "Ingen eksisterende arkiv på: $ARCHIVE_PATH"
      ;;
    download)
      need_cmd curl
      log "Downloader fra archive.org reference-linket: $ARCHIVE_URL"
      curl -L --fail --continue-at - --output "$ARCHIVE_PATH.download" "$ARCHIVE_URL"
      mv -f "$ARCHIVE_PATH.download" "$ARCHIVE_PATH"
      ;;
    archive)
      [[ -n "${ARCHIVE_INPUT:-}" ]] || fatal "Ingen lokal arkivsti angivet"
      [[ -f "$ARCHIVE_INPUT" ]] || fatal "Lokalt arkiv findes ikke: $ARCHIVE_INPUT"
      cp -f "$ARCHIVE_INPUT" "$ARCHIVE_PATH"
      ;;
    *) fatal "Intern fejl: ukendt mode '$MODE'" ;;
  esac
  validate_archive
}

extract_game() {
  mkdir -p "$EXTRACT_DIR" "$GAME_DIR" "$LOGDIR"
  if [[ ! -f "$DISK_IMG" ]]; then
    log "Udpakker 7z-arkivet til privat source-cache"
    rm -rf "$EXTRACT_DIR"
    mkdir -p "$EXTRACT_DIR"
    7z x -y -o"$EXTRACT_DIR" "$ARCHIVE_PATH" >"$LOGDIR/extract-archive.log"
  fi
  [[ -f "$DISK_IMG" ]] || fatal "disk1.img mangler efter arkivudpakning: $DISK_IMG"

  log "Udpakker DOS-floppy-image til runtime"
  rm -rf "$GAME_DIR"
  mkdir -p "$GAME_DIR"
  7z x -y -o"$GAME_DIR" "$DISK_IMG" >"$LOGDIR/extract-disk.log"

  for required in GWR.COM GWR.EXE LEVSP.BIN ALSP1.BIN ALSP2.BIN PATS1 PATS2 GAMEON.PCM GAMEOVER.PCM GWRTITLE.PCM; do
    [[ -f "$GAME_DIR/$required" ]] || fatal "Mangler efter udpakning: $required"
  done
  log "Runtime klar: $GAME_DIR"
}

main() {
  parse_args "$@"
  [[ -n "$MODE" ]] || choose_mode
  acquire_archive
  extract_game
  if [[ "$LAUNCH_AFTER" == 1 ]]; then
    log "Starter spillet via launch.sh"
    exec env GWR_ARCHIVE="$ARCHIVE_PATH" GWR_RUNTIME_DIR="$RUNTIME_DIR" "$HERE/launch.sh"
  else
    log "Færdig. Start senere med: cd '$HERE' && ./launch.sh"
  fi
}

main "$@"
