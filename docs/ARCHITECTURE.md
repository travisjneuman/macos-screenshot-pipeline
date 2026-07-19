# Architecture

## Problem

Users want, simultaneously:

1. High practical quality on HDR/XDR displays  
2. Paste-friendly images for non-Apple apps  
3. Automatic Photos / iCloud archive  
4. No permanent Desktop pile  
5. Fast markup without a paid suite  
6. Stock capture shortcuts (`⌘⇧3/4/5`)  
7. Near-zero idle CPU for the capture path  

Stock macOS offers save-to-folder **or** clipboard, not folder + clipboard + Photos, and HDR capture often produces **HEIF** even when the preference type is `png`.

## Dual-path decision

| Path | Carrier | Consumer |
|------|---------|----------|
| Archive | Original `screencapture` bytes (HEIF when HDR) | Photos / iCloud |
| Share | `sips` → PNG → clipboard `«class PNGf»` | Everywhere else |

Never claim one blob is both max-HDR archive and universal lossless PNG.

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
           │              ┌──────────┼──────────┐
           │              ▼                     ▼
           │        clipboard PNG         Photos import
           │        (sips+osascript)      (original file)
           │                                   │
           └──── delete staging on success ────┘
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
| Clipboard PNG | Log; continue to Photos if enabled |
| Photos import | **Retain** staging file |
| Delete staging | Only if success policy allows |

## Security / TCC

- Logs: paths, sizes, status strings — **not** pixels.  
- No network I/O from this project.  
- Automation (Photos) and Accessibility (hotkey) only.  
- Ad-hoc codesign on the hotkey app unless the user notarizes later.

## Public identifiers

See [REFERENCE.md](REFERENCE.md) for paths and LaunchAgent labels (`com.travisjneuman.screenshotpipeline.*`).
