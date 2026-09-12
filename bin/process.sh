#!/bin/bash
# macos-screenshot-pipeline — process files already written to the staging folder
#
# Triggered by launchd WatchPaths on the staging directory.
# Idle cost: none (no daemon loop). Runs only when staging changes, then exits.
#
# Per batch (order is intentional and matches the docs):
#   0. screencapture (not this script) already saved the file into staging
#   1. Wait until file size is stable
#   2. Put a paste-ready PNG on the clipboard as quickly as possible
#      (direct copy for real PNGs; conversion/downsampling only when needed)
#   3. After clipboard work for all ready images, if IMPORT_PHOTOS=1: import original bytes into the Photos app library
#      (iCloud Photos sync is Photos/macOS — this script does not upload)
#   4. Maybe delete staging:
#        - never if DELETE_STAGING_ON_SUCCESS=0
#        - never if IMPORT_PHOTOS=1 and Photos import failed
#        - otherwise delete when DELETE_STAGING_ON_SUCCESS=1

set -euo pipefail

CONFIG_FILE="${MACOS_SCREENSHOT_PIPELINE_CONFIG:-$HOME/.config/macos-screenshot-pipeline/config.env}"
# shellcheck disable=SC1090
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

STAGING="${STAGING_DIR:-${SCREENSHOT_STAGING:-$HOME/Pictures/Camera Roll}}"
LOG_DIR="${HOME}/Library/Logs"
LOG_FILE="${LOG_DIR}/macos-screenshot-pipeline.log"
STATE_DIR="${HOME}/.local/state/macos-screenshot-pipeline"
LOCK_FILE="${STATE_DIR}/process.lock"
CACHE_DIR="${HOME}/Library/Caches/macos-screenshot-pipeline"
CLIPBOARD_TMP=""
CAPTION="${CAPTION:-Screenshot}"
NOTE_KEYWORD="${KEYWORD:-Screenshot}"
IMPORT_PHOTOS="${IMPORT_PHOTOS:-1}"
DELETE_STAGING_ON_SUCCESS="${DELETE_STAGING_ON_SUCCESS:-1}"
CLIPBOARD_MAX_DIMENSION="${CLIPBOARD_MAX_DIMENSION:-3840}"

PHOTOS_STATE_CHECKED=0
QUIT_PHOTOS_ON_EXIT=0

mkdir -p "$LOG_DIR" "$STATE_DIR"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

# Querying "running" does not launch Photos. If detection fails, leave it open.
prepare_photos() {
  [[ "$PHOTOS_STATE_CHECKED" == "0" ]] || return 0
  PHOTOS_STATE_CHECKED=1
  local running
  if running="$(/usr/bin/osascript -e 'application "Photos" is running' 2>&1)"; then
    if [[ "$running" == "false" ]]; then
      QUIT_PHOTOS_ON_EXIT=1
    fi
  else
    log "photos: could not determine prior state; leaving open :: $running"
  fi
}

cleanup() {
  local status=$? result
  trap - EXIT
  if [[ "$QUIT_PHOTOS_ON_EXIT" == "1" ]]; then
    if result="$(/usr/bin/osascript -e 'if application "Photos" is running then tell application "Photos" to quit' 2>&1)"; then
      log "photos: requested quit (not running before pipeline import)"
    else
      log "photos: quit failed :: $result"
    fi
  fi
  [[ -z "$CLIPBOARD_TMP" ]] || rm -f "$CLIPBOARD_TMP"
  exit "$status"
}

is_image() {
  local f="$1" base ext
  base="${f##*/}"
  case "$base" in
    .*|desktop.ini|Thumbs.db|\$RECYCLE.BIN) return 1 ;;
  esac
  case "$base" in
    *.download|*.tmp|*.part) return 1 ;;
  esac
  ext="$(printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    png|jpg|jpeg|heic|heif|tif|tiff|gif|webp) return 0 ;;
    *) return 1 ;;
  esac
}

is_real_png() {
  local magic
  magic="$(/usr/bin/od -An -tx1 -N8 "$1" 2>/dev/null | tr -d '[:space:]')"
  [[ "$magic" == "89504e470d0a1a0a" ]]
}

image_exceeds_clipboard_limit() {
  local src="$1" dimensions width height
  [[ "$CLIPBOARD_MAX_DIMENSION" =~ ^[0-9]+$ ]] || return 1
  [[ "$CLIPBOARD_MAX_DIMENSION" -gt 0 ]] || return 1

  dimensions="$(/usr/bin/sips -g pixelWidth -g pixelHeight "$src" 2>/dev/null)" || return 1
  width=""; height=""
  local label value
  while read -r label value; do
    case "$label" in
      pixelWidth:) width="$value" ;;
      pixelHeight:) height="$value" ;;
    esac
  done <<< "$dimensions"
  [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || return 1
  [[ "$width" -gt "$CLIPBOARD_MAX_DIMENSION" || "$height" -gt "$CLIPBOARD_MAX_DIMENSION" ]]
}

# Include identity and timestamps so replacements/rewrites are not just size checks.
file_signature() {
  stat -f '%d:%i:%z:%m:%c' "$1" 2>/dev/null
}

wait_stable() {
  local f="$1" a b i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [[ -f "$f" ]] || return 1
    a="$(file_signature "$f")" || return 1
    sleep 0.15
    b="$(file_signature "$f")" || return 1
    if [[ "$a" == "$b" && -s "$f" ]]; then
      STABLE_SIGNATURE="$b"
      return 0
    fi
  done
  return 1
}

copy_png_to_clipboard() {
  local src="$1" paste_source tmp="" mode="direct" started_at elapsed size
  local resize=0
  started_at="$(date +%s)"

  if image_exceeds_clipboard_limit "$src"; then
    resize=1
  fi

  # Apple may write HEIF bytes under a .png filename when HDR capture is on.
  # Real PNGs can go straight to the pasteboard unless the share copy is oversized.
  if is_real_png "$src" && [[ "$resize" == "0" ]]; then
    paste_source="$src"
  else
    mkdir -p "$CACHE_DIR" || return 1
    tmp="$(mktemp "${CACHE_DIR}/ss-clip.XXXXXX")" || return 1
    CLIPBOARD_TMP="$tmp"
    paste_source="$tmp"
    mode="converted"
    if [[ "$resize" == "1" ]]; then
      mode="resized-max-${CLIPBOARD_MAX_DIMENSION}px"
      if ! /usr/bin/sips -Z "$CLIPBOARD_MAX_DIMENSION" -s format png "$src" --out "$tmp" >/dev/null 2>&1; then
        log "clipboard: sips resize failed for $src"
        rm -f "$tmp"
        return 1
      fi
    elif ! /usr/bin/sips -s format png "$src" --out "$tmp" >/dev/null 2>&1; then
      log "clipboard: sips conversion failed for $src"
      rm -f "$tmp"
      return 1
    fi
  fi

  if /usr/bin/osascript - "$paste_source" <<'APPLESCRIPT' >/dev/null 2>&1
on run argv
  set imagePath to POSIX file (item 1 of argv)
  set the clipboard to (read imagePath as «class PNGf»)
end run
APPLESCRIPT
  then
    elapsed=$(( $(date +%s) - started_at ))
    size="$(stat -f%z "$paste_source" 2>/dev/null || echo 0)"
    log "clipboard: PNG ready (${size} bytes; ${mode}; ${elapsed}s)"
    [[ -n "$tmp" ]] && rm -f "$tmp"
    CLIPBOARD_TMP=""
    return 0
  fi
  log "clipboard: osascript failed for $src"
  [[ -n "$tmp" ]] && rm -f "$tmp"
  CLIPBOARD_TMP=""
  return 1
}

import_to_photos() {
  local src="$1" result
  result="$(/usr/bin/osascript - "$src" "$CAPTION" "$NOTE_KEYWORD" <<'APPLESCRIPT' 2>&1
on run argv
  set imagePath to POSIX file (item 1 of argv)
  set captionText to item 2 of argv
  set keywordText to item 3 of argv
  tell application "Photos"
    set importedItems to import {imagePath} with skip check duplicates
    repeat with mediaItem in importedItems
      try
        set description of mediaItem to captionText
      end try
      try
        set keywords of mediaItem to {keywordText}
      end try
      try
        if (name of mediaItem is missing value) or (name of mediaItem is "") then
          set name of mediaItem to captionText
        end if
      end try
    end repeat
    return (count of importedItems) as text
  end tell
end run
APPLESCRIPT
)" || {
    log "photos: import failed for $src :: $result"
    return 1
  }

  if [[ "$result" =~ ^[0-9]+$ ]] && [[ "$result" -ge 1 ]]; then
    log "photos: imported $result item(s) caption='${CAPTION}' :: ${src##*/}"
    return 0
  fi
  log "photos: unexpected result '$result' for $src"
  return 1
}

maybe_delete_staging() {
  local f="$1"
  if [[ "$DELETE_STAGING_ON_SUCCESS" != "1" ]]; then
    log "retain: DELETE_STAGING_ON_SUCCESS=0 :: ${f##*/}"
    return 0
  fi
  if rm -f "$f"; then
    log "cleanup: removed staging ${f##*/}"
  else
    log "cleanup: failed to remove $f"
  fi
}

archive_file() {
  local f="$1" signature="$2" clipboard_ok="$3" photos_ok=1
  if [[ "$(file_signature "$f")" != "$signature" ]]; then
    log "retain: changed after clipboard preparation: $f"
    return 0
  fi

  if [[ "$IMPORT_PHOTOS" == "1" ]]; then
    prepare_photos
    if ! import_to_photos "$f"; then
      photos_ok=0
      log "retain: left in staging after Photos failure: $f"
    fi
  else
    log "photos: skipped (IMPORT_PHOTOS=0)"
  fi

  if [[ "$(file_signature "$f")" != "$signature" ]]; then
    log "retain: changed during Photos import: $f"
  elif [[ "$IMPORT_PHOTOS" == "1" && "$photos_ok" == "1" ]] ||
       [[ "$IMPORT_PHOTOS" != "1" && "$clipboard_ok" == "1" ]]; then
    maybe_delete_staging "$f"
  elif [[ "$IMPORT_PHOTOS" != "1" ]]; then
    log "retain: clipboard failed with Photos disabled: $f"
  fi
  log "process: finished (clipboard_ok=${clipboard_ok} photos_ok=${photos_ok}) :: ${f##*/}"
}

main() {
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  log "wake: scanning staging '$STAGING'"
  [[ -d "$STAGING" ]] || {
    log "error: staging folder missing: $STAGING"
    return 0
  }

  local f count=0 clipboard_ok signature i started_at
  local ready_files=() signatures=() clipboard_results=()
  started_at="$(date +%s)"
  # Do all interactive clipboard work before waiting for any Photos imports.
  while IFS= read -r -d '' f; do
    if is_image "$f"; then
      log "process: $f"
      if ! wait_stable "$f"; then
        log "retain: not stable or disappeared: $f"
        continue
      fi
      signature="$STABLE_SIGNATURE"
      clipboard_ok=0
      if copy_png_to_clipboard "$f"; then clipboard_ok=1; fi
      ready_files[count]="$f"
      signatures[count]="$signature"
      clipboard_results[count]="$clipboard_ok"
      count=$((count + 1))
    fi
  done < <(find "$STAGING" -maxdepth 1 -type f -print0 2>/dev/null)

  for ((i=0; i<count; i++)); do
    archive_file "${ready_files[i]}" "${signatures[i]}" "${clipboard_results[i]}"
  done
  if [[ "$count" -eq 0 ]]; then
    log "idle: no ready image files to process"
  else
    log "done: processed $count image(s) in $(( $(date +%s) - started_at ))s"
  fi
}

if [[ "${MACOS_SCREENSHOT_PIPELINE_TESTING:-0}" != "1" ]]; then
  if [[ "${1:-}" != "--lock-held" ]]; then
    # Native kernel lock: never expires under a live worker, released on exit/crash.
    # Keep its inode so simultaneous callers cannot acquire different lock files.
    exec /usr/bin/lockf -k -s -t 0 "$LOCK_FILE" /bin/bash "$0" --lock-held
  fi
  main
fi
