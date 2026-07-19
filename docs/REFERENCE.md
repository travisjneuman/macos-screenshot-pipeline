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
| `CAPTION` | `Screenshot` | Photos `description`; also `name` if empty |
| `KEYWORD` | `Screenshot` | Photos `keywords` array (single entry) |
| `IMPORT_PHOTOS` | `1` | `0` skips Photos |
| `DELETE_STAGING_ON_SUCCESS` | `1` (installer sets `0` with `--no-photos` or `--keep-staging`) | `0` keeps files after a successful run |
| `ENABLE_HDR` | `1` | Used by prefs helper only |
| `SHOW_THUMBNAIL` | `0` | Used by prefs helper only |

Override config path: `MACOS_SCREENSHOT_PIPELINE_CONFIG=/path/to/file`.

Legacy env still honored for staging: `SCREENSHOT_STAGING`.

**Delete rule (code):** delete only if `DELETE_STAGING_ON_SUCCESS=1` and (`IMPORT_PHOTOS≠1` or Photos import succeeded). Clipboard is attempted regardless.

## Log lines (examples)

Happy path order (Photos on):

```text
wake: scanning staging '…'
process: /…/Screenshot ….png
photos: imported 1 item(s) caption='Screenshot' :: Screenshot ….png
clipboard: PNG ready (N bytes)
cleanup: removed staging Screenshot ….png
done: processed 1 image(s)
```

Other lines:

```text
photos: skipped (IMPORT_PHOTOS=0)
photos: import failed …
retain: left in staging after Photos failure: …
retain: DELETE_STAGING_ON_SUCCESS=0 :: …
clipboard: sips failed …
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
