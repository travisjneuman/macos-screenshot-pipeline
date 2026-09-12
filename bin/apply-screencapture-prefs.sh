#!/bin/bash
# Apply screenshot system preferences for macos-screenshot-pipeline.
# Safe to re-run. Honors config.env and SCREENSHOT_STAGING.
set -euo pipefail

CONFIG_FILE="${MACOS_SCREENSHOT_PIPELINE_CONFIG:-$HOME/.config/macos-screenshot-pipeline/config.env}"
# shellcheck disable=SC1090
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

LOCATION="${STAGING_DIR:-${SCREENSHOT_STAGING:-$HOME/Pictures/Camera Roll}}"
ENABLE_HDR="${ENABLE_HDR:-1}"
SHOW_THUMBNAIL="${SHOW_THUMBNAIL:-0}"
CAPTURE_DELAY="${CAPTURE_DELAY:-0}"
case "$CAPTURE_DELAY" in
  0|5|10) ;;
  *) echo "CAPTURE_DELAY must be 0, 5, or 10 seconds" >&2; exit 64 ;;
esac

mkdir -p "$LOCATION"
defaults write com.apple.screencapture location "$LOCATION"

if [[ "$ENABLE_HDR" == "1" ]]; then
  defaults write com.apple.screencapture captureHDR -bool true
else
  defaults write com.apple.screencapture captureHDR -bool false
fi

defaults write com.apple.screencapture type png
defaults write com.apple.screencapture captureDelay -int "$CAPTURE_DELAY"

if [[ "$SHOW_THUMBNAIL" == "1" ]]; then
  defaults write com.apple.screencapture show-thumbnail -bool true
else
  defaults write com.apple.screencapture show-thumbnail -bool false
fi

# Best-effort if thumbnail is re-enabled later.
defaults write com.apple.screencaptureui thumbnailExpiration -float 2.5

killall SystemUIServer 2>/dev/null || true
killall screencaptureui 2>/dev/null || true

echo "Applied screencapture prefs → $LOCATION (HDR=${ENABLE_HDR}, thumbnail=${SHOW_THUMBNAIL}, delay=${CAPTURE_DELAY}s)"
defaults read com.apple.screencapture 2>/dev/null || true
