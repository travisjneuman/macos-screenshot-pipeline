# Test matrix (manual)

Target: current release acceptance.

| # | Case | Steps | Expected |
|---|------|-------|----------|
| 1 | Fresh install | Clean user or VM; `./install.sh` | Exit 0; agents load; config written |
| 2 | Capture paste | ⌘⇧4 → ⌘V in Notes | Image pastes |
| 3 | Capture web paste | ⌘V in Chromium-based app if available | Image pastes |
| 4 | Clipboard then Photos import | Default install; capture | Log shows clipboard before Photos; item in Recents; caption set |
| 5 | Staging cleanup | After Photos success + clipboard | Staging has no screenshot file; cleanup log line present |
| 6 | Photos failure retain | Deny Automation; capture | File remains; log import failed |
| 7 | Markup hotkey | Accessibility on; ⌘⇧E | Preview opens clipboard image |
| 8 | No clipboard image | Clear clipboard; ⌘⇧E | Notification; no crash |
| 9 | `--no-photos` | Reinstall with flag; capture | PNG clipboard; file kept; no import |
| 10 | `--no-hotkey` | Install | Capture works; no hotkey agent |
| 11 | Uninstall | `./uninstall.sh` | Agents gone; capture stops |
| 12 | Reinstall | `./install.sh` again | Idempotent success |
| 13 | `--purge` | After uninstall --purge | libexec/config/apps removed |
| 14 | Stock restore | `--restore-stock-screenshots` | Desktop location behavior restored |
| 15 | Static smoke | `./scripts/smoke-test.sh` | Exit 0 |
| 16 | 6K share optimization | Capture a full 5K/6K display | Clipboard log reports `resized-max-3840px`; Photos retains original dimensions |
| 17 | Native-resolution opt-out | Install with `--clipboard-full-resolution`; capture | Clipboard is not resized |

## Environment notes

Record OS version, chip, HDR display yes/no, and date when filling results.

## Automated coverage

`scripts/smoke-test.sh` covers structure, shell syntax, plist tokens, Swift compile (if `swiftc`), and absence of private absolute host paths. It does **not** replace GUI/TCC tests.
