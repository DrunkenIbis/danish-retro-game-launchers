#!/usr/bin/env bash
# Generic ISO download/import installer for game recipes.
#
# Usage from games/<game-id>/install.sh:
#   GAME_ID="my-game"
#   GAME_TITLE="My Game"
#   INSTALLER_DOWNLOAD_URL="https://example.invalid/MyGame.iso"
#   # Or, for multi-file media such as BIN/CUE:
#   # INSTALLER_DOWNLOAD_FILES=("game.bin|https://example.invalid/game.bin" "game.cue|https://example.invalid/game.cue")
#   # INSTALLER_POST_ACQUIRE_HOOK="my_game_make_iso_from_bin_cue"
#   INSTALLER_ISO_NAME="MyGame.iso"
#   INSTALLER_ISO_ENV_VAR="MYGAME_ISO"              # optional
#   INSTALLER_SOURCE_DIR_ENV_VAR="MYGAME_SOURCE_DIR" # optional
#   INSTALLER_CD_DEVICE_ENV_VAR="MYGAME_CD_DEVICE"   # optional
#   INSTALLER_REQUIRED_IMAGE_PATHS=("GAME.EXE" "DATA/INTRO.DAT")
#   source "$REPO_ROOT/scripts/iso-installer.sh"
#   iso_installer_main "$@"

set -euo pipefail

iso_installer_log() { printf '[%s] %s\n' "${GAME_TITLE:-$GAME_ID}" "$*"; }
iso_installer_fatal() { printf '[%s] FEJL: %s\n' "${GAME_TITLE:-$GAME_ID}" "$*" >&2; exit 1; }
iso_installer_need_cmd() { command -v "$1" >/dev/null 2>&1 || iso_installer_fatal "Mangler kommando: $1"; }

iso_installer_var_value() {
  local name="$1"
  if [[ -n "$name" ]]; then
    printf '%s' "${!name-}"
  fi
}

iso_installer_init_defaults() {
  [[ -n "${GAME_ID:-}" ]] || iso_installer_fatal "GAME_ID er ikke sat i install.sh"
  GAME_TITLE="${GAME_TITLE:-$GAME_ID}"
  INSTALLER_ISO_NAME="${INSTALLER_ISO_NAME:-$GAME_ID.iso}"
  INSTALLER_DOWNLOAD_LABEL="${INSTALLER_DOWNLOAD_LABEL:-download reference-linket}"
  INSTALLER_LAUNCH_SCRIPT="${INSTALLER_LAUNCH_SCRIPT:-$HERE/launch.sh}"
  if ! declare -p INSTALLER_REQUIRED_IMAGE_PATHS >/dev/null 2>&1; then
    INSTALLER_REQUIRED_IMAGE_PATHS=()
  fi
  if ! declare -p INSTALLER_DOWNLOAD_FILES >/dev/null 2>&1; then
    INSTALLER_DOWNLOAD_FILES=()
  fi

  SOURCE_BASE="${RETRO_GAME_SOURCE_DIR:-$REPO_ROOT/local/sources}"
  local source_dir_override iso_override cd_override
  source_dir_override="$(iso_installer_var_value "${INSTALLER_SOURCE_DIR_ENV_VAR:-}")"
  iso_override="$(iso_installer_var_value "${INSTALLER_ISO_ENV_VAR:-}")"
  cd_override="$(iso_installer_var_value "${INSTALLER_CD_DEVICE_ENV_VAR:-}")"

  SOURCE_DIR="${source_dir_override:-$SOURCE_BASE/$GAME_ID}"
  ISO_PATH="${iso_override:-$SOURCE_DIR/$INSTALLER_ISO_NAME}"
  CD_DEVICE="${cd_override:-}"
  LAUNCH_AFTER=1
  MODE=""
}

iso_installer_usage() {
  cat <<EOF
Brug: $0 [valg]

Interaktiv installer/importer for ${GAME_TITLE}.

Valg:
  --existing           brug ISO'en der allerede ligger i source-mappen
  --download           download ISO'en fra reference-linket
  --cd [device]        lav en ISO fra et CD/DVD-drev, fx --cd /dev/sr0
  --iso PATH           skriv/brug ISO på denne sti
  --no-launch          stop efter import/download; start ikke spillet
  --launch             start spillet efter import/download (default)
  -h, --help           vis hjælp

Miljøvariabler:
  RETRO_GAME_SOURCE_DIR  base-map til private spilfiler
  RETRO_GAME_RUNTIME_DIR base-map til runtime/extracted data, brugt af launch.sh
EOF
  if [[ -n "${INSTALLER_ISO_ENV_VAR:-}" ]]; then
    printf '  %-22s konkret ISO-sti\n' "$INSTALLER_ISO_ENV_VAR"
  fi
  if [[ -n "${INSTALLER_SOURCE_DIR_ENV_VAR:-}" ]]; then
    printf '  %-22s konkret source-map\n' "$INSTALLER_SOURCE_DIR_ENV_VAR"
  fi
  if [[ -n "${INSTALLER_CD_DEVICE_ENV_VAR:-}" ]]; then
    printf '  %-22s CD/DVD-device til --cd\n' "$INSTALLER_CD_DEVICE_ENV_VAR"
  fi
  if [[ ${#INSTALLER_REQUIRED_IMAGE_PATHS[@]} -gt 0 ]]; then
    echo
    echo "ISO-validering kræver disse filer:"
    local path
    for path in "${INSTALLER_REQUIRED_IMAGE_PATHS[@]}"; do
      printf '  - %s\n' "$path"
    done
  fi
}

iso_installer_parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --existing) MODE="existing"; shift ;;
      --download) MODE="download"; shift ;;
      --cd)
        MODE="cd"
        if [[ $# -gt 1 && "${2:-}" != --* ]]; then CD_DEVICE="$2"; shift 2; else shift; fi
        ;;
      --iso) [[ $# -gt 1 ]] || iso_installer_fatal "--iso kræver en sti"; ISO_PATH="$2"; shift 2 ;;
      --no-launch) LAUNCH_AFTER=0; shift ;;
      --launch) LAUNCH_AFTER=1; shift ;;
      -h|--help) iso_installer_usage; exit 0 ;;
      *) iso_installer_fatal "Ukendt valg: $1" ;;
    esac
  done
}

iso_installer_ask_choice() {
  local has_iso=0
  [[ -f "$ISO_PATH" ]] && has_iso=1
  echo
  iso_installer_log "ISO-sti: $ISO_PATH"
  echo
  if [[ "$has_iso" == 1 ]]; then
    echo "Der findes allerede en ISO. Hvad vil du gøre?"
    echo "  1) Brug eksisterende ISO"
    echo "  2) Download igen fra reference-linket og overskriv"
    echo "  3) Importér fra CD/DVD-drev og overskriv"
    echo "  q) Afbryd"
    printf '> '
    read -r choice
    case "$choice" in
      1) MODE="existing" ;;
      2) MODE="download" ;;
      3) MODE="cd" ;;
      q|Q) exit 0 ;;
      *) iso_installer_fatal "Ugyldigt valg" ;;
    esac
  else
    echo "Der findes ingen ISO endnu. Hvad vil du gøre?"
    echo "  1) Download fra reference-linket"
    echo "  2) Importér fra CD/DVD-drev"
    echo "  q) Afbryd"
    printf '> '
    read -r choice
    case "$choice" in
      1) MODE="download" ;;
      2) MODE="cd" ;;
      q|Q) exit 0 ;;
      *) iso_installer_fatal "Ugyldigt valg" ;;
    esac
  fi
}

iso_installer_select_cd_device() {
  if [[ -n "$CD_DEVICE" ]]; then
    [[ -b "$CD_DEVICE" ]] || iso_installer_fatal "CD/DVD-device findes ikke eller er ikke block device: $CD_DEVICE"
    return 0
  fi

  iso_installer_log "Finder optiske drev..."
  local devices choice i
  mapfile -t devices < <(lsblk -ndo NAME,TYPE,RM,MODEL | awk '$2=="rom" || $1 ~ /^sr[0-9]+$/ {print "/dev/"$1" "$0}')
  if [[ ${#devices[@]} -eq 0 ]]; then
    echo "Kunne ikke finde et optisk drev automatisk. Skriv device manuelt, fx /dev/sr0:"
    printf '> '
    read -r CD_DEVICE
  elif [[ ${#devices[@]} -eq 1 ]]; then
    CD_DEVICE="${devices[0]%% *}"
    iso_installer_log "Bruger fundet drev: $CD_DEVICE"
  else
    echo "Vælg CD/DVD-drev:"
    i=1
    for d in "${devices[@]}"; do echo "  $i) $d"; i=$((i+1)); done
    printf '> '
    read -r choice
    [[ "$choice" =~ ^[0-9]+$ ]] || iso_installer_fatal "Ugyldigt valg"
    (( choice >= 1 && choice <= ${#devices[@]} )) || iso_installer_fatal "Ugyldigt valg"
    CD_DEVICE="${devices[$((choice-1))]%% *}"
  fi
  [[ -b "$CD_DEVICE" ]] || iso_installer_fatal "CD/DVD-device findes ikke eller er ikke block device: $CD_DEVICE"
}

iso_installer_list_image_paths() {
  local image="$1"
  7z l -slt "$image" | awk -F' = ' '$1 == "Path" && $2 != "" {print $2}'
}

iso_installer_run_post_acquire_hook() {
  if [[ -n "${INSTALLER_POST_ACQUIRE_HOOK:-}" ]]; then
    if ! declare -F "$INSTALLER_POST_ACQUIRE_HOOK" >/dev/null 2>&1; then
      iso_installer_fatal "INSTALLER_POST_ACQUIRE_HOOK peger på ukendt funktion: $INSTALLER_POST_ACQUIRE_HOOK"
    fi
    iso_installer_log "Kører efterbehandling: $INSTALLER_POST_ACQUIRE_HOOK"
    "$INSTALLER_POST_ACQUIRE_HOOK"
  fi
}

iso_installer_download_reference_files() {
  iso_installer_need_cmd curl
  if [[ ${#INSTALLER_DOWNLOAD_FILES[@]} -gt 0 ]]; then
    local entry filename url tmp
    for entry in "${INSTALLER_DOWNLOAD_FILES[@]}"; do
      filename="${entry%%|*}"
      url="${entry#*|}"
      [[ -n "$filename" && -n "$url" && "$filename" != "$url" ]] || iso_installer_fatal "Ugyldig INSTALLER_DOWNLOAD_FILES entry: $entry"
      mkdir -p "$SOURCE_DIR"
      tmp="$SOURCE_DIR/$filename.download"
      iso_installer_log "Downloader fra ${INSTALLER_DOWNLOAD_LABEL}: $url"
      curl -L --fail --continue-at - --output "$tmp" "$url"
      mv -f "$tmp" "$SOURCE_DIR/$filename"
    done
  else
    [[ -n "${INSTALLER_DOWNLOAD_URL:-}" ]] || iso_installer_fatal "INSTALLER_DOWNLOAD_URL mangler i install.sh"
    local tmp
    iso_installer_log "Downloader fra ${INSTALLER_DOWNLOAD_LABEL}: $INSTALLER_DOWNLOAD_URL"
    tmp="$ISO_PATH.download"
    curl -L --fail --continue-at - --output "$tmp" "$INSTALLER_DOWNLOAD_URL"
    mv -f "$tmp" "$ISO_PATH"
  fi
  iso_installer_run_post_acquire_hook
}

iso_installer_validate_image() {
  local image="$1"
  [[ -f "$image" ]] || iso_installer_fatal "ISO blev ikke fundet: $image"
  iso_installer_need_cmd 7z

  if [[ ${#INSTALLER_REQUIRED_IMAGE_PATHS[@]} -eq 0 ]]; then
    iso_installer_log "Ingen INSTALLER_REQUIRED_IMAGE_PATHS sat; validerer kun at image kan læses"
    7z l "$image" >/dev/null || iso_installer_fatal "Image kunne ikke læses af 7z: $image"
    return 0
  fi

  iso_installer_log "Validerer ISO-indhold tidligt..."
  local list_file required missing=0
  list_file="$(mktemp)"
  if ! iso_installer_list_image_paths "$image" > "$list_file"; then
    rm -f "$list_file"
    iso_installer_fatal "Image kunne ikke læses af 7z: $image"
  fi
  for required in "${INSTALLER_REQUIRED_IMAGE_PATHS[@]}"; do
    if ! grep -Fxqi -- "$required" "$list_file"; then
      printf '[%s] Mangler i ISO: %s\n' "${GAME_TITLE}" "$required" >&2
      missing=1
    fi
  done
  rm -f "$list_file"
  [[ "$missing" == 0 ]] || iso_installer_fatal "ISO'en matcher ikke opskriften. Forkert fil, dårlig download eller dårlig CD-import."
}

iso_installer_run_launch() {
  [[ -x "$INSTALLER_LAUNCH_SCRIPT" ]] || iso_installer_fatal "Launcher mangler eller er ikke eksekverbar: $INSTALLER_LAUNCH_SCRIPT"
  iso_installer_log "Starter spillet via $(basename "$INSTALLER_LAUNCH_SCRIPT")"
  if [[ -n "${INSTALLER_ISO_ENV_VAR:-}" ]]; then
    exec env "${INSTALLER_ISO_ENV_VAR}=$ISO_PATH" "$INSTALLER_LAUNCH_SCRIPT"
  else
    exec "$INSTALLER_LAUNCH_SCRIPT"
  fi
}

iso_installer_main() {
  iso_installer_init_defaults
  iso_installer_parse_args "$@"
  mkdir -p "$(dirname "$ISO_PATH")"

  if [[ -z "$MODE" ]]; then
    iso_installer_ask_choice
  fi

  case "$MODE" in
    existing)
      if [[ ! -f "$ISO_PATH" && -n "${INSTALLER_POST_ACQUIRE_HOOK:-}" ]]; then
        iso_installer_run_post_acquire_hook
      fi
      [[ -f "$ISO_PATH" ]] || iso_installer_fatal "Ingen eksisterende ISO på: $ISO_PATH"
      iso_installer_validate_image "$ISO_PATH"
      ;;
    download)
      iso_installer_download_reference_files
      iso_installer_validate_image "$ISO_PATH"
      ;;
    cd)
      iso_installer_need_cmd dd
      iso_installer_select_cd_device
      iso_installer_log "Laver ISO fra $CD_DEVICE -> $ISO_PATH"
      echo "Sørg for at CD'en er sat i drevet. Dette kan tage et stykke tid."
      local tmp
      tmp="$ISO_PATH.importing"
      rm -f "$tmp"
      dd if="$CD_DEVICE" of="$tmp" bs=2048 conv=noerror,sync status=progress
      mv -f "$tmp" "$ISO_PATH"
      iso_installer_validate_image "$ISO_PATH"
      ;;
    *) iso_installer_fatal "Intern fejl: ukendt mode '$MODE'" ;;
  esac

  iso_installer_log "ISO klar: $ISO_PATH"
  if [[ "$LAUNCH_AFTER" == 1 ]]; then
    iso_installer_run_launch
  else
    iso_installer_log "Færdig. Start senere med:"
    echo "  cd '$HERE' && ./launch.sh"
  fi
}
