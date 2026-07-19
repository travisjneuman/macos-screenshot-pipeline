# Reference

## Paths

| Role | Path |
|------|------|
| Scripts | `~/.local/libexec/macos-screenshot-pipeline/` |
| Config | `~/.config/macos-screenshot-pipeline/config.env` |
| State / lock | `~/.local/state/macos-screenshot-pipeline/` |
| Edit cache | `~/Library/Caches/macos-screenshot-pipeline/` |
| Primary log | `~/Library/Logs/macos-screenshot-pipeline.log` |
| Hotkey app | `~/Applications/Screenshot Pipeline Hotkey.app` |
| Default staging | `~/Pictures/Camera Roll` |

## LaunchAgents

| Label | Plist |
|-------|-------|
| `com.travisjneuman.screenshotpipeline.capture` | `~/Library/LaunchAgents/…capture.plist` |
| `com.travisjneuman.screenshotpipeline.hotkey` | `~/Library/LaunchAgents/…hotkey.plist` |

Bundle id (hotkey app): `com.travisjneuman.screenshotpipeline.hotkey`

## config.env keys

| Key | Default | Meaning |
|-----|---------|---------|
| `STAGING_DIR` | `~/Pictures/Camera Roll` | Watch + scan directory |
| `CAPTION` | `Screenshot` | Photos description / name fallback |
| `KEYWORD` | `Screenshot` | Photos keyword |
| `IMPORT_PHOTOS` | `1` | `0` skips Photos |
| `DELETE_STAGING_ON_SUCCESS` | `1` | `0` keeps files |
| `ENABLE_HDR` | `1` | Prefs helper |
| `SHOW_THUMBNAIL` | `0` | Prefs helper |

Override config path: `MACOS_SCREENSHOT_PIPELINE_CONFIG=/path/to/file`.

Legacy env still honored for staging: `SCREENSHOT_STAGING`.

## Log lines (examples)

```text
wake: scanning staging '…'
clipboard: PNG ready (N bytes)
photos: imported 1 item(s) caption='Screenshot' :: Screenshot ….png
cleanup: removed staging …
retain: left in staging after Photos failure: …
edit: opening Preview for clipboard-edit-….png
idle: no image files to process
skip: another process holds lock
```

## Image extensions processed

`png`, `jpg`, `jpeg`, `heic`, `heif`, `tif`, `tiff`, `gif`, `webp`

Ignored: dotfiles, `desktop.ini`, `*.tmp`, `*.download`, `*.part`.

## System preferences touched

Domain `com.apple.screencapture`: `location`, `captureHDR`, `type`, `show-thumbnail`  
Domain `com.apple.screencaptureui`: `thumbnailExpiration` (best-effort)
