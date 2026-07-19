# Test matrix (manual)

Target: **v0.1.0** acceptance.

| # | Case | Steps | Expected |
|---|------|-------|----------|
| 1 | Fresh install | Clean user or VM; `./install.sh` | Exit 0; agents load; config written |
| 2 | Capture paste | ⌘⇧4 → ⌘V in Notes | Image pastes |
| 3 | Capture web paste | ⌘V in Chromium-based app if available | Image pastes |
| 4 | Photos import | Default install; capture | Item in Recents; caption set |
| 5 | Staging cleanup | After success | Staging has no screenshot file |
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

## Environment notes

Record OS version, chip, HDR display yes/no, and date when filling results.

## Automated coverage

`scripts/smoke-test.sh` covers structure, shell syntax, plist tokens, Swift compile (if `swiftc`), and absence of private absolute host paths. It does **not** replace GUI/TCC tests.
