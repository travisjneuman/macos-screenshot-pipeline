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
case "$ENABLE_HDR" in
  0|1) ;;
  *) echo "ENABLE_HDR must be 0 or 1" >&2; exit 64 ;;
esac
case "$CAPTURE_DELAY" in
  0|5|10) ;;
  *) echo "CAPTURE_DELAY must be 0, 5, or 10 seconds" >&2; exit 64 ;;
esac

MACOS_VERSION="$(/usr/bin/sw_vers -productVersion)"
MACOS_MAJOR="${MACOS_VERSION%%.*}"
if [[ ! "$MACOS_MAJOR" =~ ^[0-9]+$ ]]; then
  echo "Could not determine macOS major version from '$MACOS_VERSION'" >&2
  exit 1
fi

# macOS 26+ supports native HDR screenshots in HEIF. Earlier releases use the
# compatible SDR/PNG path; forcing PNG while HDR is enabled can make ImageIO
# fail while writing the native screenshot before our watcher ever runs.
if [[ "$ENABLE_HDR" == "1" ]] && (( MACOS_MAJOR >= 26 )); then
  CAPTURE_HDR=true
  CAPTURE_TYPE=heic
  CAPTURE_FORMAT="HDR/HEIC"
else
  CAPTURE_HDR=false
  CAPTURE_TYPE=png
  CAPTURE_FORMAT="SDR/PNG"
fi

mkdir -p "$LOCATION"
defaults write com.apple.screencapture location "$LOCATION"
defaults write com.apple.screencapture captureHDR -bool "$CAPTURE_HDR"
defaults write com.apple.screencapture type "$CAPTURE_TYPE"
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

echo "Applied screencapture prefs → $LOCATION (capture=${CAPTURE_FORMAT}, thumbnail=${SHOW_THUMBNAIL}, delay=${CAPTURE_DELAY}s)"
defaults read com.apple.screencapture 2>/dev/null || true
