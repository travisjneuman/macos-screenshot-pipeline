# Architecture

## Problem

Users want, simultaneously:

1. High practical quality on HDR/XDR displays  
2. Paste-friendly images for non-Apple apps  
3. Automatic Photos library archive (iCloud only if the user already syncs Photos)  
4. No permanent Desktop pile  
5. Fast markup without a paid suite  
6. Stock capture shortcuts (`⌘⇧3/4/5`)  
7. Near-zero idle CPU for the capture path  

Stock macOS offers save-to-folder **or** clipboard, not folder + clipboard + Photos, and HDR capture often produces **HEIF** even when the preference type is `png`.

## Dual-path decision

| Path | Carrier | Consumer |
|------|---------|----------|
| Archive | Original `screencapture` bytes (HEIF when HDR) | Photos.app library (optional iCloud sync afterward) |
| Share | `sips` → PNG → clipboard `«class PNGf»` | Everywhere else |

Never claim one blob is both max-HDR archive and universal lossless PNG.

**Processing order after the file lands in staging** (see also [BEHAVIOR.md](BEHAVIOR.md)):

1. Import **original** into Photos when `IMPORT_PHOTOS=1`  
2. Convert a **PNG** onto the clipboard (**always attempted**)  
3. **Delete** the staging file only when delete rules allow (Photos must have succeeded if Photos is enabled; `DELETE_STAGING_ON_SUCCESS` must be `1`)

Staging always comes first — system `screencapture` writes the file; this project only reacts afterward.

## Data flow

```text
  ⌘⇧3 / ⌘⇧4 / ⌘⇧5
           │
           ▼
  screencapture (location=staging, HDR on, thumbnail off)
           │
           ▼
  staging directory  ──FSEvents──▶  launchd WatchPaths
           │                              │
           │                              ▼
           │                     process.sh (exit when done)
           │                         │
           │                         ▼
           │              Photos import (original file)
           │              [skipped if IMPORT_PHOTOS=0]
           │                         │
           │                         ▼
           │              clipboard PNG (sips + osascript)
           │              [always attempted]
           │                         │
           └──── delete staging if rules allow ────┘
```

Markup path (independent):

```text
  ⌘⇧E  →  hotkey app  →  edit-clipboard-in-preview.sh  →  Preview
```

## Components

| Component | Role | Lifetime |
|-----------|------|----------|
| `process.sh` | Batch process staging images | Start → finish → exit |
| Capture LaunchAgent | `WatchPaths` on staging | Loaded; process not kept alive |
| `hotkey-agent.swift` | Carbon `RegisterEventHotKey` | Accessory app, event-driven |
| Hotkey LaunchAgent | `RunAtLoad` + `KeepAlive` | Keeps accessory running |
| `config.env` | Staging, caption, flags | Read per invocation |

## Resource model

- **No polling loop** on the capture path.  
- Empty WatchPaths wakes (deletes/metadata) must stay cheap — lock + scan + idle log.  
- Single-flight lock via atomic `mkdir` (no `flock` on macOS by default). Stale lock > 120s cleared.  
- Hotkey agent blocks on NSRunLoop; no timers for the hotkey itself.

## Failure policy

| Step | On failure |
|------|------------|
| Photos import fails | Log; **retain** staging; **still** run clipboard PNG |
| Clipboard PNG fails | Log; do not undo Photos import; delete still follows Photos/delete rules |
| Delete staging | `DELETE_STAGING_ON_SUCCESS=1` **and** (Photos off **or** Photos succeeded) |

## Security / TCC

- Logs: paths, sizes, status strings — **not** pixels.  
- No network I/O from this project.  
- Automation (Photos) and Accessibility (hotkey) only.  
- Ad-hoc codesign on the hotkey app unless the user notarizes later.

## Public identifiers

See [REFERENCE.md](REFERENCE.md) for paths and LaunchAgent labels (`com.travisjneuman.screenshotpipeline.*`).
