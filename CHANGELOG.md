# Changelog

All notable changes to this project are documented in this file.

## [0.1.0] — 2026-07-19

### Added

- Event-driven capture pipeline via launchd `WatchPaths` (no polling).
- Dual-path processing: true PNG on clipboard; original bytes into Photos.
- Configurable staging directory, caption, keyword, Photos on/off, staging retention.
- Global markup hotkey **⌘⇧E** (Carbon accessory app) → Preview.
- `install.sh` / `uninstall.sh` with flags for hotkey, Photos, prefs restore, purge.
- User config at `~/.config/macos-screenshot-pipeline/config.env`.
- Docs: architecture, user guide, install, operations, troubleshooting, reference, test matrix.
- MIT license.

### Notes

- Extracted and generalized from a production-proven private macOS host setup.
- Public LaunchAgent labels use `com.travisjneuman.screenshotpipeline.*`.
