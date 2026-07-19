#!/bin/bash
# Uninstall macos-screenshot-pipeline agents (and optionally files / stock prefs).
set -euo pipefail

HOME_DIR="${HOME}"
UID_NUM="$(id -u)"
DOMAIN="gui/${UID_NUM}"
AGENTS="${HOME_DIR}/Library/LaunchAgents"
LIBEXEC="${HOME_DIR}/.local/libexec/macos-screenshot-pipeline"
CONFIG_DIR="${HOME_DIR}/.config/macos-screenshot-pipeline"
APPS="${HOME_DIR}/Applications"

LABEL_CAPTURE="com.travisjneuman.screenshotpipeline.capture"
LABEL_HOTKEY="com.travisjneuman.screenshotpipeline.hotkey"

RESTORE_STOCK=0
PURGE=0

usage() {
  cat <<'EOF'
Usage: ./uninstall.sh [options]

  --restore-stock-screenshots   Reset location to Desktop and re-enable thumbnail
  --purge                       Remove libexec, config, cache, state, and apps
  -h, --help                    Show this help

Does not delete anything from the Photos library.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --restore-stock-screenshots) RESTORE_STOCK=1; shift ;;
    --purge) PURGE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

echo "==> Unloading LaunchAgents"
launchctl bootout "${DOMAIN}/${LABEL_CAPTURE}" 2>/dev/null || true
launchctl bootout "${DOMAIN}/${LABEL_HOTKEY}" 2>/dev/null || true
rm -f "$AGENTS/${LABEL_CAPTURE}.plist" "$AGENTS/${LABEL_HOTKEY}.plist"

if [[ "$RESTORE_STOCK" == "1" ]]; then
  echo "==> Restoring stock screencapture defaults (Desktop + thumbnail)"
  defaults delete com.apple.screencapture location 2>/dev/null || true
  defaults write com.apple.screencapture show-thumbnail -bool true
  # Leave captureHDR alone (hardware/user preference).
  killall SystemUIServer 2>/dev/null || true
  killall screencaptureui 2>/dev/null || true
fi

if [[ "$PURGE" == "1" ]]; then
  echo "==> Purging installed files"
  rm -rf "$LIBEXEC"
  rm -rf "$CONFIG_DIR"
  rm -rf "${HOME_DIR}/.local/state/macos-screenshot-pipeline"
  rm -rf "${HOME_DIR}/Library/Caches/macos-screenshot-pipeline"
  rm -rf "${APPS}/Screenshot Pipeline Hotkey.app"
  rm -rf "${APPS}/Edit Clipboard in Preview.app"
  # Logs kept unless user deletes them (useful forensics).
else
  echo "Scripts/config left in place. Use --purge to remove:"
  echo "  $LIBEXEC"
  echo "  $CONFIG_DIR"
fi

echo "Done. Photos library was not modified."
