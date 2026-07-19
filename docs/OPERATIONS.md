# Operations

## Health check

```bash
UID_NUM="$(id -u)"

launchctl print "gui/${UID_NUM}/com.travisjneuman.screenshotpipeline.capture" \
  | egrep 'state =|runs =|last exit|WatchPaths' || echo "capture agent missing"

launchctl print "gui/${UID_NUM}/com.travisjneuman.screenshotpipeline.hotkey" \
  | egrep 'state =|runs =|pid =|last exit' || echo "hotkey agent missing"

defaults read com.apple.screencapture location
defaults read com.apple.screencapture show-thumbnail
defaults read com.apple.screencapture captureHDR

ls -la "${HOME}/Pictures/Camera Roll" 2>/dev/null || true
tail -30 "${HOME}/Library/Logs/macos-screenshot-pipeline.log" 2>/dev/null || true
```

**Healthy idle:**

- Capture job: loaded, **not running**, last exit 0, WatchPaths set.  
- Hotkey job: **running** with a pid (if installed).  
- Staging: no leftover screenshot images (default mode).  
- Log order per shot: `photos: imported`, then `clipboard: PNG ready`, then `cleanup: removed staging`.

## Manual process run

```bash
~/.local/libexec/macos-screenshot-pipeline/process.sh
```

## Restart agents

```bash
UID_NUM="$(id -u)"
DOMAIN="gui/${UID_NUM}"
AGENTS="${HOME}/Library/LaunchAgents"

launchctl bootout "${DOMAIN}/com.travisjneuman.screenshotpipeline.capture" 2>/dev/null || true
launchctl bootstrap "${DOMAIN}" "${AGENTS}/com.travisjneuman.screenshotpipeline.capture.plist"

launchctl bootout "${DOMAIN}/com.travisjneuman.screenshotpipeline.hotkey" 2>/dev/null || true
launchctl bootstrap "${DOMAIN}" "${AGENTS}/com.travisjneuman.screenshotpipeline.hotkey.plist"
```

Or re-run `./install.sh` from the repo (idempotent).

## Logs

| File | Content |
|------|---------|
| `~/Library/Logs/macos-screenshot-pipeline.log` | Processor + edit script |
| `~/Library/Logs/macos-screenshot-pipeline.launchd.*.log` | Capture agent stdio |
| `~/Library/Logs/macos-screenshot-pipeline-hotkey.*.log` | Hotkey agent stdio |

## Rebuild hotkey app only

```bash
LIBEXEC="${HOME}/.local/libexec/macos-screenshot-pipeline"
swiftc -O -o "$LIBEXEC/hotkey-agent" "$LIBEXEC/hotkey-agent.swift"
# then re-run install.sh or copy into the .app and codesign -s - --force --deep
```

After rebuild, macOS may require re-approving Accessibility.
