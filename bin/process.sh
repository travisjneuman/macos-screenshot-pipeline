#!/bin/bash
# macos-screenshot-pipeline — process files already written to the staging folder
#
# Triggered by launchd WatchPaths on the staging directory.
# Idle cost: none (no daemon loop). Runs only when staging changes, then exits.
#
# Per image (order is intentional and matches the docs):
#   0. screencapture (not this script) already saved the file into staging
#   1. Wait until file size is stable
#   2. Put a paste-ready PNG on the clipboard as quickly as possible
#      (direct copy for real PNGs; conversion/downsampling only when needed)
#   3. If IMPORT_PHOTOS=1: import original bytes into the Photos app library
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
LOCK_DIR="${STATE_DIR}/process.lock.d"
CAPTION="${CAPTION:-Screenshot}"
NOTE_KEYWORD="${KEYWORD:-Screenshot}"
IMPORT_PHOTOS="${IMPORT_PHOTOS:-1}"
DELETE_STAGING_ON_SUCCESS="${DELETE_STAGING_ON_SUCCESS:-1}"
CLIPBOARD_MAX_DIMENSION="${CLIPBOARD_MAX_DIMENSION:-3840}"

mkdir -p "$LOG_DIR" "$STATE_DIR"

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

# Portable single-flight lock (macOS has no flock util).
# mkdir is atomic; stale locks older than 2 minutes are cleared.
acquire_lock() {
  if mkdir "$LOCK_DIR" 2>/dev/null; then
    echo "$$" >"${LOCK_DIR}/pid"
    trap 'rm -rf "$LOCK_DIR"' EXIT INT TERM
    return 0
  fi
  if [[ -d "$LOCK_DIR" ]]; then
    local mtime age
    mtime=$(stat -f%m "$LOCK_DIR" 2>/dev/null || echo 0)
    age=$(( $(date +%s) - mtime ))
    if [[ "$age" -gt 120 ]]; then
      log "lock: clearing stale lock (${age}s)"
      rm -rf "$LOCK_DIR"
      if mkdir "$LOCK_DIR" 2>/dev/null; then
        echo "$$" >"${LOCK_DIR}/pid"
        trap 'rm -rf "$LOCK_DIR"' EXIT INT TERM
        return 0
      fi
    fi
  fi
  return 1
}

is_image() {
  local f="$1" base ext
  base="$(basename "$f")"
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
  width="$(printf '%s\n' "$dimensions" | awk '/pixelWidth:/ { print $2; exit }')"
  height="$(printf '%s\n' "$dimensions" | awk '/pixelHeight:/ { print $2; exit }')"
  [[ "$width" =~ ^[0-9]+$ && "$height" =~ ^[0-9]+$ ]] || return 1
  [[ "$width" -gt "$CLIPBOARD_MAX_DIMENSION" || "$height" -gt "$CLIPBOARD_MAX_DIMENSION" ]]
}

wait_stable() {
  local f="$1" a b i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [[ -f "$f" ]] || return 1
    a=$(stat -f%z "$f" 2>/dev/null || echo 0)
    sleep 0.15
    b=$(stat -f%z "$f" 2>/dev/null || echo 0)
    if [[ "$a" == "$b" && "$a" -gt 0 ]]; then
      return 0
    fi
  done
  [[ -f "$f" ]] || return 1
  return 0
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
    tmp="$(mktemp "${TMPDIR:-/tmp}/ss-clip.XXXXXX.png")"
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
    return 0
  fi
  log "clipboard: osascript failed for $src"
  [[ -n "$tmp" ]] && rm -f "$tmp"
  return 1
}

# Escape for embedding inside an AppleScript double-quoted string.
as_escape() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

import_to_photos() {
  local src="$1" result
  local cap_e key_e
  cap_e="$(as_escape "$CAPTION")"
  key_e="$(as_escape "$NOTE_KEYWORD")"

  result="$(/usr/bin/osascript <<APPLESCRIPT 2>&1
set imagePath to POSIX file "${src}"
tell application "Photos"
  set importedItems to import {imagePath} with skip check duplicates
  repeat with mediaItem in importedItems
    try
      set description of mediaItem to "${cap_e}"
    end try
    try
      set keywords of mediaItem to {"${key_e}"}
    end try
    try
      if (name of mediaItem is missing value) or (name of mediaItem is "") then
        set name of mediaItem to "${cap_e}"
      end if
    end try
  end repeat
  return (count of importedItems) as text
end tell
APPLESCRIPT
)" || {
    log "photos: import failed for $src :: $result"
    return 1
  }

  if [[ "$result" =~ ^[0-9]+$ ]] && [[ "$result" -ge 1 ]]; then
    log "photos: imported $result item(s) caption='${CAPTION}' :: $(basename "$src")"
    return 0
  fi
  log "photos: unexpected result '$result' for $src"
  return 1
}

maybe_delete_staging() {
  local f="$1"
  if [[ "$DELETE_STAGING_ON_SUCCESS" != "1" ]]; then
    log "retain: DELETE_STAGING_ON_SUCCESS=0 :: $(basename "$f")"
    return 0
  fi
  if rm -f "$f"; then
    log "cleanup: removed staging $(basename "$f")"
  else
    log "cleanup: failed to remove $f"
  fi
}

process_file() {
  local f="$1" started_at clipboard_ok=0 photos_ok=1
  started_at="$(date +%s)"
  log "process: $f"

  if ! wait_stable "$f"; then
    log "skip: disappeared before stable: $f"
    return 0
  fi

  # Clipboard is the interactive handoff, so never block it behind Photos.
  if copy_png_to_clipboard "$f"; then
    clipboard_ok=1
  fi

  if [[ "$IMPORT_PHOTOS" == "1" ]]; then
    if import_to_photos "$f"; then
      photos_ok=1
    else
      photos_ok=0
      log "retain: left in staging after Photos failure: $f"
    fi
  else
    log "photos: skipped (IMPORT_PHOTOS=0)"
  fi

  if [[ "$IMPORT_PHOTOS" != "1" ]] || [[ "$photos_ok" == "1" ]]; then
    maybe_delete_staging "$f"
  fi

  log "process: finished in $(( $(date +%s) - started_at ))s (clipboard_ok=${clipboard_ok} photos_ok=${photos_ok}) :: $(basename "$f")"
}

main() {
  if ! acquire_lock; then
    log "skip: another process holds lock"
    exit 0
  fi

  log "wake: scanning staging '$STAGING'"
  [[ -d "$STAGING" ]] || {
    log "error: staging folder missing: $STAGING"
    exit 0
  }

  local f count=0
  while IFS= read -r -d '' f; do
    if is_image "$f"; then
      process_file "$f"
      count=$((count + 1))
    fi
  done < <(find "$STAGING" -maxdepth 1 -type f -print0 2>/dev/null)

  if [[ "$count" -eq 0 ]]; then
    log "idle: no image files to process"
  else
    log "done: processed $count image(s)"
  fi
}

if [[ "${MACOS_SCREENSHOT_PIPELINE_TESTING:-0}" != "1" ]]; then
  main "$@"
  exit 0
fi
