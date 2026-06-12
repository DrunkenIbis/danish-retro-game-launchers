#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ISO="${BB_ISO:-$BASE_DIR/BEAST.iso}"
INSTALL_DIR="${BB_INSTALL_DIR:-$BASE_DIR/battle-beast-extracted}"
WINEPREFIX="${BB_WINEPREFIX:-${WINEPREFIX:-}}"
WINEARCH="${BB_WINEARCH:-}"
WINE_BIN="${BB_WINE_BIN:-}"
SEVEN_Z_BIN="${BB_7Z_BIN:-7z}"
BB_VIRTUAL_DESKTOP="${BB_VIRTUAL_DESKTOP:-1}"
BB_DESKTOP_SIZE="${BB_DESKTOP_SIZE:-640x480}"
BB_DESKTOP_NAME="${BB_DESKTOP_NAME:-BattleBeast}"
MARKER="$INSTALL_DIR/.battle-beast-installed"
SETUP_EXE="$INSTALL_DIR/SETUP.EXE"

resolve_bin() {
  local name="$1"
  local fallback="$2"
  if command -v "$name" >/dev/null 2>&1; then
    command -v "$name"
    return 0
  fi
  if [ -n "$fallback" ] && [ -x "$fallback" ]; then
    printf '%s\n' "$fallback"
    return 0
  fi
  return 1
}

log() {
  printf '%s\n' "$*"
}

die() {
  log "Fejl: $*"
  exit 1
}

find_launch_exe() {
  local candidate
  if [ -n "${BB_LAUNCH_EXE:-}" ] && [ -f "${BB_LAUNCH_EXE:-}" ]; then
    printf '%s\n' "$BB_LAUNCH_EXE"
    return 0
  fi

  for candidate in \
    "$INSTALL_DIR/BEAST/BEAST.EXE" \
    "$INSTALL_DIR/BEAST.EXE" \
    "$INSTALL_DIR/WIN95/LAUNCH.EXE" \
    "$INSTALL_DIR/BEAST/WIN95/LAUNCH.EXE" \
    "$INSTALL_DIR/BEAST/LAUNCH.EXE"; do
    if [ -f "$candidate" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

extract_iso() {
  if [ -f "$SETUP_EXE" ] && [ -f "$INSTALL_DIR/WIN95/LAUNCH.EXE" ]; then
    return 0
  fi

  require_cmd "$SEVEN_Z_BIN"
  mkdir -p "$INSTALL_DIR"
  log "Udpakker ISO til: $INSTALL_DIR"
  "$SEVEN_Z_BIN" x -y "-o$INSTALL_DIR" "$ISO" >/dev/null
}

ensure_prefix() {
  if [ ! -d "$WINEPREFIX" ] || [ ! -f "$WINEPREFIX/system.reg" ]; then
    log "Forbereder Wine-prefix: $WINEPREFIX"
    mkdir -p "$WINEPREFIX"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "$1 er ikke installeret eller ikke i PATH"
}

wine_env_cmd() {
  if [ -n "$WINEARCH" ]; then
    WINEPREFIX="$WINEPREFIX" WINEARCH="$WINEARCH" "$WINE_BIN" "$@"
  else
    WINEPREFIX="$WINEPREFIX" "$WINE_BIN" "$@"
  fi
}

run_setup_if_needed() {
  if [ "${BB_RUN_SETUP:-0}" != "1" ]; then
    log "Springer installer over som standard; brug BB_RUN_SETUP=1 for at teste SETUP.EXE."
    return 0
  fi

  if [ -f "$MARKER" ] || [ "${BB_SKIP_SETUP:-0}" = "1" ]; then
    return 0
  fi

  if [ -x "$MARKER" ]; then
    return 0
  fi

  if [ ! -f "$SETUP_EXE" ]; then
    return 0
  fi

  log "Kører installer: $SETUP_EXE"
  local setup_status=0
  ( cd "$INSTALL_DIR" && wine_env_cmd ./SETUP.EXE ) || setup_status=$?
  if [ "$setup_status" -ne 0 ]; then
    log "Advarsel: installeren afsluttede med status $setup_status."
    log "Fortsætter alligevel til launcher, fordi discen indeholder WIN95/LAUNCH.EXE."
    log "Brug BB_REQUIRE_SETUP=1 hvis scriptet skal stoppe ved installer-fejl."
    if [ "${BB_REQUIRE_SETUP:-0}" = "1" ]; then
      return "$setup_status"
    fi
    return 0
  fi
  mkdir -p "$INSTALL_DIR"
  : > "$MARKER"
}

main() {
  if [ -n "$WINE_BIN" ]; then
    WINE_BIN="$(resolve_bin "$WINE_BIN" /usr/bin/wine32)" || WINE_BIN="$(resolve_bin wine /usr/bin/wine)" || die "wine er ikke installeret eller ikke i PATH"
  elif command -v wine32 >/dev/null 2>&1; then
    WINE_BIN="$(command -v wine32)"
  else
    WINE_BIN="$(resolve_bin wine /usr/bin/wine)" || die "wine er ikke installeret eller ikke i PATH"
  fi

  SEVEN_Z_BIN="$(resolve_bin "$SEVEN_Z_BIN" /usr/bin/7z)" || die "7z er ikke installeret eller ikke i PATH"

  if [ -z "$WINEPREFIX" ]; then
    case "$(basename "$WINE_BIN")" in
      wine32) WINEPREFIX="$BASE_DIR/wineprefix32" ;;
      *) WINEPREFIX="$BASE_DIR/wineprefix" ;;
    esac
  fi

  if [ -z "$WINEARCH" ] && [ "$(basename "$WINE_BIN")" = "wine32" ]; then
    WINEARCH=win32
  fi

  [ -f "$ISO" ] || die "ISO-filen blev ikke fundet: $ISO"

  if [ "${BB_DRY_RUN:-0}" = "1" ]; then
    log "DRY RUN"
    log "WINE_BIN=$WINE_BIN"
    log "SEVEN_Z_BIN=$SEVEN_Z_BIN"
    log "ISO=$ISO"
    log "INSTALL_DIR=$INSTALL_DIR"
    log "WINEPREFIX=$WINEPREFIX"
    log "WINEARCH=$WINEARCH"
    log "BB_VIRTUAL_DESKTOP=$BB_VIRTUAL_DESKTOP"
    log "BB_DESKTOP_SIZE=$BB_DESKTOP_SIZE"
    exit 0
  fi

  if [ "$WINEARCH" = "win32" ] && [ "$(basename "$WINE_BIN")" != "wine32" ]; then
    die "Denne Wine-installation kører i wow64-mode og understøtter ikke WINEARCH=win32. Brug wine32 eller lad scriptet vælge wine32 automatisk."
  fi

  extract_iso
  ensure_prefix
  run_setup_if_needed

  local launch_exe
  if ! launch_exe="$(find_launch_exe)"; then
    if [ -f "$SETUP_EXE" ]; then
      log "Kunne ikke finde launcher; forsøger SETUP.EXE igen: $SETUP_EXE"
      if [ -n "$WINEARCH" ]; then
        exec env WINEPREFIX="$WINEPREFIX" WINEARCH="$WINEARCH" "$WINE_BIN" "$SETUP_EXE"
      else
        exec env WINEPREFIX="$WINEPREFIX" "$WINE_BIN" "$SETUP_EXE"
      fi
    fi
    die "Kunne ikke finde nogen startfil i $INSTALL_DIR"
  fi

  log "Starter spillet: $launch_exe"
  local launch_rel="${launch_exe#$INSTALL_DIR/}"
  local launch_dir
  local launch_file
  launch_dir="$(dirname "$launch_rel")"
  launch_file="$(basename "$launch_rel")"
  if [ -n "$WINEARCH" ]; then
    if [ "$BB_VIRTUAL_DESKTOP" = "1" ]; then
      exec env WINEPREFIX="$WINEPREFIX" WINEARCH="$WINEARCH" bash -lc 'cd "$1/$2" && exec "$3" explorer "/desktop=$5,$6" "./$4"' _ "$INSTALL_DIR" "$launch_dir" "$WINE_BIN" "$launch_file" "$BB_DESKTOP_NAME" "$BB_DESKTOP_SIZE"
    else
      exec env WINEPREFIX="$WINEPREFIX" WINEARCH="$WINEARCH" bash -lc 'cd "$1/$2" && exec "$3" "./$4"' _ "$INSTALL_DIR" "$launch_dir" "$WINE_BIN" "$launch_file"
    fi
  else
    if [ "$BB_VIRTUAL_DESKTOP" = "1" ]; then
      exec env WINEPREFIX="$WINEPREFIX" bash -lc 'cd "$1/$2" && exec "$3" explorer "/desktop=$5,$6" "./$4"' _ "$INSTALL_DIR" "$launch_dir" "$WINE_BIN" "$launch_file" "$BB_DESKTOP_NAME" "$BB_DESKTOP_SIZE"
    else
      exec env WINEPREFIX="$WINEPREFIX" bash -lc 'cd "$1/$2" && exec "$3" "./$4"' _ "$INSTALL_DIR" "$launch_dir" "$WINE_BIN" "$launch_file"
    fi
  fi
}

main "$@"
