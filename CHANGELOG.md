# Changelog

All notable changes to this project are documented in this file.

## [0.1.0] — 2026-07-19

### Documentation

- Authoritative [docs/BEHAVIOR.md](docs/BEHAVIOR.md) matching `process.sh` order and delete rules.
- Clarified Photos **library import** vs iCloud sync; clipboard runs after Photos attempt; staging deleted only on allowed success paths.

### Added

- Event-driven capture pipeline via launchd `WatchPaths` (no polling).
- Dual-path processing in order: staging file → original into Photos → true PNG on clipboard → delete staging.
- Configurable staging directory, caption, keyword, Photos on/off, staging retention.
- Global markup hotkey **⌘⇧E** (Carbon accessory app) → Preview.
- `install.sh` / `uninstall.sh` with flags for hotkey, Photos, prefs restore, purge.
- User config at `~/.config/macos-screenshot-pipeline/config.env`.
- Docs: architecture, user guide, install, operations, troubleshooting, reference, test matrix.
- MIT license.

### Notes

- Extracted and generalized from a production-proven private macOS host setup.
- Public LaunchAgent labels use `com.travisjneuman.screenshotpipeline.*`.
