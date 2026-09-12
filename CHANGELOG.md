# Changelog

All notable changes to this project are documented in this file.

## [Unreleased]

### Changed

- Clipboard preparation now precedes all Photos imports within each batch.
- Preview skips re-encoding PNG clipboard data and preserves the TIFF fallback.
- Capture timer defaults to zero; `CAPTURE_DELAY=5` or `10` remains configurable.
- Native kernel locking replaces age-based stale-lock deletion.
- Unstable/replaced files and failed clipboard-only handoffs are retained; quoted Photos arguments are handled safely.
- Photos quits after the batch only when it was initially closed; existing background sessions remain open.
- Conversion scratch files use the application cache with exit cleanup.

- Clipboard is populated before Photos import so archive responsiveness cannot delay paste.
- Real PNG captures bypass re-encoding when they already fit the configured share size.
- Clipboard images now default to a 3840px longest edge while Photos retains the untouched original; native-resolution paste remains available by flag or config.
- The capture LaunchAgent uses interactive scheduling and a one-second throttle for lower wake latency.
- Clipboard and per-file logs now report processing mode and elapsed time.

## [0.1.0] — 2026-07-19

### Documentation

- Authoritative [docs/BEHAVIOR.md](docs/BEHAVIOR.md) matching `process.sh` order and delete rules.
- Clarified Photos **library import** vs iCloud sync and staging deletion rules as shipped in v0.1.0.

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
