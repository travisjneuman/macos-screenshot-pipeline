#!/bin/bash
# Open the current clipboard image in Preview (markup toolbar when permitted).
# Default global hotkey: ⌘⇧E via Screenshot Pipeline Hotkey.app

set -u

CONFIG_FILE="${MACOS_SCREENSHOT_PIPELINE_CONFIG:-$HOME/.config/macos-screenshot-pipeline/config.env}"
# shellcheck disable=SC1090
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

LOG_DIR="${HOME}/Library/Logs"
LOG_FILE="${LOG_DIR}/macos-screenshot-pipeline.log"
CACHE_DIR="${HOME}/Library/Caches/macos-screenshot-pipeline"
mkdir -p "$LOG_DIR" "$CACHE_DIR"

log() {
  printf '%s edit: %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_FILE"
}

find "$CACHE_DIR" -type f -name 'clipboard-edit-*.png' -mtime +1 -delete 2>/dev/null || true

OUT="${CACHE_DIR}/clipboard-edit-$(date +%Y%m%d-%H%M%S)-$$.png"

if ! /usr/bin/osascript <<APPLESCRIPT >/dev/null 2>&1
set outPath to "${OUT}"
set wrote to false
try
  set pngData to the clipboard as «class PNGf»
  set fRef to open for access POSIX file outPath with write permission
  try
    set eof fRef to 0
    write pngData to fRef
    set wrote to true
  end try
  close access fRef
on error
  try
    close access POSIX file outPath
  end try
end try

if wrote is false then
  try
    set tiffData to the clipboard as «class TIFF»
    set fRef to open for access POSIX file outPath with write permission
    try
      set eof fRef to 0
      write tiffData to fRef
      set wrote to true
    end try
    close access fRef
  on error
    try
      close access POSIX file outPath
    end try
  end try
end if

if wrote is false then error "no image on clipboard"
APPLESCRIPT
then
  log "no image on clipboard"
  /usr/bin/osascript -e 'display notification "Copy or capture an image first." with title "Screenshot Pipeline" subtitle "No image on clipboard"' 2>/dev/null || true
  exit 0
fi

/usr/bin/sips -s format png "$OUT" --out "$OUT" >/dev/null 2>&1 || true

if [[ ! -s "$OUT" ]]; then
  log "empty output file"
  exit 1
fi

log "opening Preview for $(basename "$OUT") ($(stat -f%z "$OUT") bytes)"

/usr/bin/osascript <<APPLESCRIPT
set imagePath to POSIX file "${OUT}"
tell application "Preview"
  activate
  open imagePath
end tell

delay 0.4

-- Best-effort: show markup toolbar. Failure must not block opening the image.
try
  tell application "System Events"
    tell process "Preview"
      set frontmost to true
      delay 0.1
      try
        click menu item "Show Markup Toolbar" of menu "View" of menu bar 1
      on error
        try
          keystroke "a" using {command down, shift down}
        end try
      end try
    end tell
  end tell
end try
APPLESCRIPT

log "Preview opened (markup auto-show is best-effort)"
exit 0
