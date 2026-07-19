# Install

## Quick start

```bash
git clone https://github.com/travisjneuman/macos-screenshot-pipeline.git
cd macos-screenshot-pipeline
./install.sh
```

Grant **Accessibility** to **Screenshot Pipeline Hotkey**. Allow **Photos** automation on first import if prompted.

## Flags

| Flag | Effect |
|------|--------|
| `--no-hotkey` | Do not build or load ⌘⇧E agent |
| `--no-photos` | Writes `IMPORT_PHOTOS=0`; also sets `DELETE_STAGING_ON_SUCCESS=0` so staging files remain |
| `--keep-staging` | Writes `DELETE_STAGING_ON_SUCCESS=0` (Photos may still run) |
| `--staging PATH` | Capture location + WatchPaths target |
| `--caption STR` | Photos description / fallback name |
| `--keyword STR` | Photos keyword |
| `--skip-prefs` | Do not write `com.apple.screencapture` |

## What install creates

| Path | Purpose |
|------|---------|
| `~/.local/libexec/macos-screenshot-pipeline/` | Scripts + built hotkey binary |
| `~/.config/macos-screenshot-pipeline/config.env` | User config |
| `~/Library/LaunchAgents/com.travisjneuman.screenshotpipeline.*.plist` | Agents |
| `~/Applications/Screenshot Pipeline Hotkey.app` | Hotkey accessory |
| `~/Applications/Edit Clipboard in Preview.app` | Optional click-to-edit helper |
| Staging dir (default Camera Roll) | Ephemeral captures |

## Behavior after install

See [BEHAVIOR.md](BEHAVIOR.md) for the authoritative pipeline:

`screencapture → staging → Photos (original) → clipboard PNG → delete staging` (defaults).

`install.sh` only installs agents/scripts/prefs; it does not capture screenshots itself.

## Preferences applied (unless `--skip-prefs`)

- `location` → staging  
- `captureHDR` → true  
- `type` → png  
- `show-thumbnail` → false  

## Legacy private install

If agents labeled `dev.neuman.screenshot-to-photos` / `dev.neuman.screenshot-edit-hotkey` are loaded, `install.sh` **unloads** them so two processors do not fight over the same folder. Old files under `~/.local/libexec/screenshot-to-photos` are left for manual removal.

## Uninstall

```bash
./uninstall.sh
./uninstall.sh --restore-stock-screenshots
./uninstall.sh --purge
```

Photos library content is never deleted by this project.

## Requirements check

```bash
command -v swiftc || echo "need Xcode CLT (or use --no-hotkey)"
test -d /System/Applications/Photos.app -o -d /Applications/Photos.app && echo photos_ok
```
