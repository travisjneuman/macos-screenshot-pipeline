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
   - `captureDelay` → 0 (`CAPTURE_DELAY=0`; optional 5 or 10 seconds)
2. User presses stock **Cmd+Shift+3 / 4 / 5** (or window mode via Space after 4).
3. **WindowServer / screencapture** writes a file into the staging directory.

### B. launchd

4. Capture LaunchAgent label: `com.travisjneuman.screenshotpipeline.capture`
5. `WatchPaths` on the staging directory fires (FSEvents). No polling loop.
6. Agent runs: `/bin/bash ~/.local/libexec/macos-screenshot-pipeline/process.sh`
7. `RunAtLoad` is false; process is **not** kept alive after exit.

### C. `process.sh` per wake

8. Acquire a native `lockf -k -s -t 0` lock on `~/.local/state/macos-screenshot-pipeline/process.lock`. A competing invocation exits 75; the kernel releases the lock when the worker exits. The empty lock file remains and must not be deleted to release a running worker.
9. `find` staging, **maxdepth 1**, files only; preserve discovery order.
10. For each image, wait up to 10 × 0.15s for a nonempty file with unchanged identity, size and modification/change timestamps. Retain files that never stabilize; do not import or delete them.
11. Attempt **clipboard work for every ready image before any Photos import**:
    - Real PNGs within `CLIPBOARD_MAX_DIMENSION` bypass conversion.
    - Other formats are converted to PNG; oversized clipboard copies are resized (default `3840`, `0` for native resolution).
    - Temporary conversion files live in the application cache and are removed after use or ordinary exit cleanup.
    - The last successful clipboard write wins, as before. This is not a multi-image clipboard format.
12. Then archive each ready image:
    - Retain and skip import if its recorded file identity/size/timestamps changed after clipboard preparation.
    - If enabled, Photos imports original bytes with `skip check duplicates`; metadata (`description`, `keywords`, missing/empty `name`) is best-effort. Success requires an integer import count ≥ 1.
    - Paths, captions and keywords are AppleScript arguments, supporting quotes and backslashes without source interpolation.
    - Delete only if the file is still unchanged, `DELETE_STAGING_ON_SUCCESS=1`, and Photos succeeded (when enabled) or the clipboard succeeded (when Photos is disabled).
    - A successful Photos import can still permit cleanup after a clipboard failure, preserving the existing archive-first retention rule.
13. Log clipboard and batch elapsed seconds plus per-file outcomes. Timings have whole-second precision and do not measure the delay before launchd starts the worker.
14. On exit, request Photos quit only if it was not running before the first import. Existing foreground/background sessions stay open. Unknown prior state leaves Photos open; empty/clipboard-only wakes do not touch it. Cleanup also runs on errors and INT/TERM, preserving exit status; quit failures are logged. Uncatchable termination cannot run app cleanup.
15. Exit 0 on normal completion, including empty wakes. No persistent poll loop or new scheduler is added. New arrivals outside the scan and retained failures remain subject to the existing WatchPaths/retry behavior; filesystem notifications are not a guaranteed durable queue.

### Default config written by `install.sh`

| Key | Default install | `--no-photos` | `--keep-staging` |
|-----|-----------------|---------------|------------------|
| `IMPORT_PHOTOS` | `1` | `0` | unchanged (1 unless also `--no-photos`) |
| `DELETE_STAGING_ON_SUCCESS` | `1` | `0` | `0` |
| `CLIPBOARD_MAX_DIMENSION` | `3840` | same | same |
| `CAPTURE_DELAY` | `0` | same | same |
| `CAPTION` / `KEYWORD` | `Screenshot` | same | same |
| `STAGING_DIR` | `~/Pictures/Camera Roll` | same unless `--staging` | same |

---

## Markup path (optional; default on)

Independent of capture processing:

1. Hotkey LaunchAgent keeps `Screenshot Pipeline Hotkey.app` running (`KeepAlive`).
2. App registers **Cmd+Shift+E** via Carbon `RegisterEventHotKey` (not remappable in v0.1).
3. On press, runs `edit-clipboard-in-preview.sh`:
   - Reads clipboard as `PNGf` or `TIFF` into `~/Library/Caches/macos-screenshot-pipeline/`
   - Preserves PNG bytes directly; converts only the TIFF fallback, stopping on conversion failure.
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
| Clipboard | **PNG**, direct when possible or produced by `sips` (typically SDR tone-map of HDR sources); max 3840px by default |

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
clipboard: PNG ready (N bytes; MODE; Ns)
photos: imported 1 item(s) caption='Screenshot' :: Screenshot ….png
cleanup: removed staging Screenshot ….png
done: processed 1 image(s) in Ns
```

Photos failure:

```text
clipboard: PNG ready …    # interactive handoff happens first
photos: import failed …
retain: left in staging after Photos failure: …
# no cleanup line
```

---

## Version

Describes tree as of the commit that added/updated this file.  
When changing `process.sh` order or delete rules, update **this file in the same PR**.
