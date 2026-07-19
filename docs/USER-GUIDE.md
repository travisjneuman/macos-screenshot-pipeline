# User guide

## Daily loops

### Capture and paste

1. **⌘⇧4** (selection), **⌘⇧3** (full screen), or **⌘⇧5** (toolbar).  
2. macOS writes the file into the **staging** folder first.  
3. The pipeline imports that **original** into Photos, then puts a **PNG** on the clipboard, then deletes the staging file (default mode).  
4. **⌘V** into Notes, Discord, browser, editor, etc.

Window capture: **⌘⇧4**, then **Space**, click the window.

### Markup (Paint-like)

1. Capture (or copy any image).  
2. **⌘⇧E** — Preview opens with the clipboard image.  
3. If the markup bar is hidden, press **⇧⌘A**.  
4. Annotate → **⌘A** → **⌘C** → paste with **⌘V**.

### What does *not* use the pipeline

| Shortcut | Behavior |
|----------|----------|
| **⌘⌃⇧4** | Native clipboard-only; **no** file, **no** Photos import |
| Touch Bar / third-party capture tools | Only if they write into your staging folder |

## Photos

With default install, each successful capture appears in Photos **Recents** with description/keyword **Screenshot** (configurable).

iCloud Photos sync is whatever you already configured. Google Photos (if you use it as a secondary sink) may or may not show Apple captions — that mapping is outside this tool.

## Staging folder

Default: `~/Pictures/Camera Roll`.

- After a **successful** Photos import (default mode), the staging file is **deleted**.  
- If Photos fails, the file **stays** so you can retry.  
- With `--no-photos`, files are **kept** unless you set `DELETE_STAGING_ON_SUCCESS=1` in config (usually unwise).

## Config

Edit:

```text
~/.config/macos-screenshot-pipeline/config.env
```

Then either wait for the next capture or run:

```bash
~/.local/libexec/macos-screenshot-pipeline/process.sh
```

Changing **staging path** also requires updating the capture LaunchAgent WatchPaths — re-run `./install.sh --staging NEWPATH` (or see OPERATIONS).

## Temporarily disable

```bash
launchctl bootout "gui/$(id -u)/com.travisjneuman.screenshotpipeline.capture"
launchctl bootout "gui/$(id -u)/com.travisjneuman.screenshotpipeline.hotkey"
```

Re-enable by re-running `./install.sh` from the clone, or `bootstrap` the plists under `~/Library/LaunchAgents/`.

## Stock screenshots again

```bash
./uninstall.sh --restore-stock-screenshots
```

That clears the custom location (Desktop default returns) and turns the floating thumbnail back on. HDR preference is left alone.
