#!/usr/bin/env bash
set -euo pipefail

GAME_ID="det-magiske-jordbaer"
ARCHIVE_URL="https://archive.org/download/det-magiske-jordbaer/DetMagiskeJordb%C3%A6r.iso"
ISO_NAME="DetMagiskeJordbaer.iso"

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
SOURCE_DIR="${DMJ_SOURCE_DIR:-$SOURCE_BASE/$GAME_ID}"
ISO_PATH="${DMJ_ISO:-$SOURCE_DIR/$ISO_NAME}"
LAUNCH_AFTER=1
MODE=""
CD_DEVICE="${DMJ_CD_DEVICE:-}"

log() { printf '[Det Magiske Jordbær] %s\n' "$*"; }
fatal() { printf '[Det Magiske Jordbær] FEJL: %s\n' "$*" >&2; exit 1; }
need_cmd() { command -v "$1" >/dev/null 2>&1 || fatal "Mangler kommando: $1"; }

usage() {
  cat <<EOF
Brug: $0 [valg]

Interaktiv installer/importer for Det Magiske Jordbær.

Valg:
  --existing           brug ISO'en der allerede ligger i source-mappen
  --download           download ISO'en fra archive.org reference-linket
  --cd [device]        lav en ISO fra et CD/DVD-drev, fx --cd /dev/sr0
  --iso PATH           skriv/brug ISO på denne sti
  --no-launch          stop efter import/download; start ikke spillet
  --launch             start spillet efter import/download (default)
  -h, --help           vis hjælp

Miljøvariabler:
  RETRO_GAME_SOURCE_DIR  base-map til private spilfiler
  RETRO_GAME_RUNTIME_DIR base-map til runtime/extracted data, brugt af launch.sh
  DMJ_ISO                konkret ISO-sti
  DMJ_CD_DEVICE          CD/DVD-device til --cd
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --existing) MODE="existing"; shift ;;
    --download) MODE="download"; shift ;;
    --cd)
      MODE="cd"
      if [[ $# -gt 1 && "${2:-}" != --* ]]; then CD_DEVICE="$2"; shift 2; else shift; fi
      ;;
    --iso) [[ $# -gt 1 ]] || fatal "--iso kræver en sti"; ISO_PATH="$2"; shift 2 ;;
    --no-launch) LAUNCH_AFTER=0; shift ;;
    --launch) LAUNCH_AFTER=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fatal "Ukendt valg: $1" ;;
  esac
done

ask_choice() {
  local has_iso=0
  [[ -f "$ISO_PATH" ]] && has_iso=1
  echo
  log "ISO-sti: $ISO_PATH"
  echo
  if [[ "$has_iso" == 1 ]]; then
    echo "Der findes allerede en ISO. Hvad vil du gøre?"
    echo "  1) Brug eksisterende ISO"
    echo "  2) Download igen fra archive.org og overskriv"
    echo "  3) Importér fra CD/DVD-drev og overskriv"
    echo "  q) Afbryd"
    printf '> '
    read -r choice
    case "$choice" in
      1) MODE="existing" ;;
      2) MODE="download" ;;
      3) MODE="cd" ;;
      q|Q) exit 0 ;;
      *) fatal "Ugyldigt valg" ;;
    esac
  else
    echo "Der findes ingen ISO endnu. Hvad vil du gøre?"
    echo "  1) Download fra archive.org"
    echo "  2) Importér fra CD/DVD-drev"
    echo "  q) Afbryd"
    printf '> '
    read -r choice
    case "$choice" in
      1) MODE="download" ;;
      2) MODE="cd" ;;
      q|Q) exit 0 ;;
      *) fatal "Ugyldigt valg" ;;
    esac
  fi
}

select_cd_device() {
  if [[ -n "$CD_DEVICE" ]]; then
    [[ -b "$CD_DEVICE" ]] || fatal "CD/DVD-device findes ikke eller er ikke block device: $CD_DEVICE"
    return 0
  fi

  log "Finder optiske drev..."
  mapfile -t devices < <(lsblk -ndo NAME,TYPE,RM,MODEL | awk '$2=="rom" || $1 ~ /^sr[0-9]+$/ {print "/dev/"$1" "$0}')
  if [[ ${#devices[@]} -eq 0 ]]; then
    echo "Kunne ikke finde et optisk drev automatisk. Skriv device manuelt, fx /dev/sr0:"
    printf '> '
    read -r CD_DEVICE
  elif [[ ${#devices[@]} -eq 1 ]]; then
    CD_DEVICE="${devices[0]%% *}"
    log "Bruger fundet drev: $CD_DEVICE"
  else
    echo "Vælg CD/DVD-drev:"
    local i=1
    for d in "${devices[@]}"; do echo "  $i) $d"; i=$((i+1)); done
    printf '> '
    read -r choice
    [[ "$choice" =~ ^[0-9]+$ ]] || fatal "Ugyldigt valg"
    (( choice >= 1 && choice <= ${#devices[@]} )) || fatal "Ugyldigt valg"
    CD_DEVICE="${devices[$((choice-1))]%% *}"
  fi
  [[ -b "$CD_DEVICE" ]] || fatal "CD/DVD-device findes ikke eller er ikke block device: $CD_DEVICE"
}

validate_iso() {
  local iso="$1"
  [[ -f "$iso" ]] || fatal "ISO blev ikke fundet: $iso"
  need_cmd 7z
  log "Validerer ISO-indhold..."
  if ! 7z l "$iso" | grep -q 'ADVENT.EXE'; then
    fatal "ISO'en ser ikke ud til at indeholde ADVENT.EXE. Forkert fil eller dårlig import?"
  fi
}

mkdir -p "$(dirname "$ISO_PATH")"

if [[ -z "$MODE" ]]; then
  ask_choice
fi

case "$MODE" in
  existing)
    [[ -f "$ISO_PATH" ]] || fatal "Ingen eksisterende ISO på: $ISO_PATH"
    validate_iso "$ISO_PATH"
    ;;
  download)
    need_cmd curl
    log "Downloader fra archive.org: $ARCHIVE_URL"
    tmp="$ISO_PATH.download"
    curl -L --fail --continue-at - --output "$tmp" "$ARCHIVE_URL"
    mv -f "$tmp" "$ISO_PATH"
    validate_iso "$ISO_PATH"
    ;;
  cd)
    need_cmd dd
    select_cd_device
    log "Laver ISO fra $CD_DEVICE -> $ISO_PATH"
    echo "Sørg for at CD'en er sat i drevet. Dette kan tage et stykke tid."
    tmp="$ISO_PATH.importing"
    rm -f "$tmp"
    dd if="$CD_DEVICE" of="$tmp" bs=2048 conv=noerror,sync status=progress
    mv -f "$tmp" "$ISO_PATH"
    validate_iso "$ISO_PATH"
    ;;
  *) fatal "Intern fejl: ukendt mode '$MODE'" ;;
esac

log "ISO klar: $ISO_PATH"

if [[ "$LAUNCH_AFTER" == 1 ]]; then
  log "Starter spillet via launch.sh"
  exec env DMJ_ISO="$ISO_PATH" "$HERE/launch.sh"
else
  log "Færdig. Start senere med:"
  echo "  cd '$HERE' && ./launch.sh"
fi
