# Behavior contract

This document describes **what the shipped code does today**.  
If README marketing and this file ever disagree, **this file + the scripts win**.

Source of truth for the capture path: [`bin/process.sh`](../bin/process.sh).  
Installer defaults: [`install.sh`](../install.sh).  
Prefs helper: [`bin/apply-screencapture-prefs.sh`](../bin/apply-screencapture-prefs.sh).  
Markup path: [`bin/hotkey-agent.swift`](../bin/hotkey-agent.swift) + [`bin/edit-clipboard-in-preview.sh`](../bin/edit-clipboard-in-preview.sh).

---

## What this project does *not* do

- It does **not** replace or reimplement macOS screenshot capture UI.
- It does **not** intercept `Cmd+Ctrl+Shift+4` (native clipboard-only); that never writes a staging file.
- It does **not** upload to iCloud, Google Photos, or any network service.
- It does **not** delete or modify existing items in the Photos library beyond **importing new** files and setting metadata on those new items.
- It does **not** guarantee the on-disk capture is a real PNG when HDR is enabled (Apple may write HEIF while the name still ends in `.png`).

---

## End-to-end capture path (default install)

### A. Before any of our code runs

1. `install.sh` (unless `--skip-prefs`) sets roughly:
   - `com.apple.screencapture location` → staging dir (default `~/Pictures/Camera Roll`)
   - `captureHDR` → true (`ENABLE_HDR=1`)
   - `type` → `png` (preference only)
   - `show-thumbnail` → false (`SHOW_THUMBNAIL=0`)
2. User presses stock **Cmd+Shift+3 / 4 / 5** (or window mode via Space after 4).
3. **WindowServer / screencapture** writes a file into the staging directory.

### B. launchd

4. Capture LaunchAgent label: `com.travisjneuman.screenshotpipeline.capture`
5. `WatchPaths` on the staging directory fires (FSEvents). No polling loop.
6. Agent runs: `/bin/bash ~/.local/libexec/macos-screenshot-pipeline/process.sh`
7. `RunAtLoad` is false; process is **not** kept alive after exit.

### C. `process.sh` per wake

8. Acquire single-flight lock (`mkdir` lock dir; stale > 120s cleared).
9. `find` staging, **maxdepth 1**, files only.
10. For each path that passes `is_image`:
    1. **wait_stable** — up to ~10 × 0.15s until size stops changing (or give up and continue).
    2. **Photos** (if `IMPORT_PHOTOS=1`):
       - `osascript` → Photos `import … with skip check duplicates`
       - On each imported item, best-effort set:
         - `description` ← `CAPTION` (default `Screenshot`)
         - `keywords` ← `{ KEYWORD }` (default `Screenshot`)
         - `name` ← `CAPTION` only if name is missing/empty
       - Success = AppleScript returns integer count ≥ 1
    3. **Clipboard** (always attempted, even if Photos failed or is disabled):
       - `sips -s format png` to a temp file
       - `osascript` set clipboard to `«class PNGf»`
       - Temp file removed
    4. **Delete staging file** via `maybe_delete_staging` only when:
       - `DELETE_STAGING_ON_SUCCESS=1`, **and**
       - either `IMPORT_PHOTOS≠1` **or** Photos import succeeded  
       Otherwise the staging file is **retained**.

11. Log to `~/Library/Logs/macos-screenshot-pipeline.log` (paths/sizes/status only).
12. Exit 0 (including idle “no images” wakes).

### Default config written by `install.sh`

| Key | Default install | `--no-photos` | `--keep-staging` |
|-----|-----------------|---------------|------------------|
| `IMPORT_PHOTOS` | `1` | `0` | unchanged (1 unless also `--no-photos`) |
| `DELETE_STAGING_ON_SUCCESS` | `1` | `0` | `0` |
| `CAPTION` / `KEYWORD` | `Screenshot` | same | same |
| `STAGING_DIR` | `~/Pictures/Camera Roll` | same unless `--staging` | same |

---

## Markup path (optional; default on)

Independent of capture processing:

1. Hotkey LaunchAgent keeps `Screenshot Pipeline Hotkey.app` running (`KeepAlive`).
2. App registers **Cmd+Shift+E** via Carbon `RegisterEventHotKey` (not remappable in v0.1).
3. On press, runs `edit-clipboard-in-preview.sh`:
   - Reads clipboard as `PNGf` or `TIFF` into `~/Library/Caches/macos-screenshot-pipeline/`
   - Opens that file in **Preview**
   - Best-effort “Show Markup Toolbar” via System Events (may need Accessibility)
   - If no image: notification; exit 0

Requires **Accessibility** for the hotkey app (and for toolbar automation).

---

## Photos and iCloud (precise)

| Claim | Accurate? |
|-------|-----------|
| Imports into **Photos.app** library | **Yes** (Automation / AppleScript) |
| Sets caption-like metadata on the **new** item | **Yes** (`description`, `keywords`, optional `name`) |
| Uploads to iCloud | **No** — not implemented here |
| May appear on other devices if user enabled iCloud Photos | **Indirectly**, via Apple’s Photos sync — outside this repo |
| Google Photos captions | **Not controlled**; any survival is best-effort |

---

## Formats (precise)

| Stage | Format |
|-------|--------|
| Staging file | Whatever screencapture wrote (often HEIF under HDR; extension may still be `.png`) |
| Photos archive | **That same original file** (import by path) |
| Clipboard | **PNG** produced by `sips` (typically SDR tone-map of HDR sources) |

---

## Extensions processed

Accepted: `png`, `jpg`, `jpeg`, `heic`, `heif`, `tif`, `tiff`, `gif`, `webp`  

Ignored: dotfiles, `desktop.ini`, `Thumbs.db`, `*.tmp`, `*.download`, `*.part`

Only **direct children** of the staging directory (`-maxdepth 1`).

---

## Expected log order (happy path, Photos on)

```text
wake: scanning staging '…'
process: /path/to/Screenshot ….png
photos: imported 1 item(s) caption='Screenshot' :: Screenshot ….png
clipboard: PNG ready (N bytes)
cleanup: removed staging Screenshot ….png
done: processed 1 image(s)
```

Photos failure:

```text
photos: import failed …
retain: left in staging after Photos failure: …
clipboard: PNG ready …    # still attempted
# no cleanup line
```

---

## Version

Describes tree as of the commit that added/updated this file.  
When changing `process.sh` order or delete rules, update **this file in the same PR**.
