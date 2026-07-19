# Roadmap

v0.1 ships a solid default path. Next work is **user control**: more knobs, clearer prefs, and features the community asks for.

Nothing here is a promise with a date. Order will shift based on real [issues](https://github.com/travisjneuman/macos-screenshot-pipeline/issues) and pull requests.

---

## Already possible today (v0.1)

| Goal | How |
|------|-----|
| Skip Photos import | `./install.sh --no-photos` or `IMPORT_PHOTOS=0` in config |
| Keep staging files | `./install.sh --keep-staging` or `DELETE_STAGING_ON_SUCCESS=0` |
| Change staging / capture folder | `./install.sh --staging PATH` (re-run so WatchPaths updates) |
| Change Photos caption / keyword | `--caption` / `--keyword` or edit `config.env` |
| Skip hotkey agent | `./install.sh --no-hotkey` |
| Leave screenshot prefs alone | `./install.sh --skip-prefs` |

See [BEHAVIOR.md](BEHAVIOR.md) and [INSTALL.md](INSTALL.md).

**Note on “iCloud Photos”:** this tool imports into **Photos.app**. It does not call iCloud APIs. Turning off Photos import (`--no-photos`) stops new shots from entering that library (and thus from any iCloud Photos sync you already use). Disabling iCloud Photos itself is a System Settings choice outside this project.

---

## Near-term customization

- **First-class config UI/docs** for every `config.env` key (discoverable, validated)
- **Clipboard format choice** — PNG (default), TIFF, JPEG, quality/scale options
- **Photos optional album** — import into a named album instead of library root only
- **Remappable markup hotkey** (not only Cmd+Shift+E)
- **Per-step toggles** without reinstall — e.g. clipboard-only for one session
- **Staging retention policies** — keep last *N*, age-based cleanup, or never delete
- **Notification opt-in** on success/failure (off by default)

---

## Medium-term

- Preferences pane or simple `msp` CLI: `msp config set clipboard.format=jpeg`
- Installer migration helper from older private label installs
- Optional Homebrew formula once the config surface is stable
- Better first-run TCC guidance (Photos Automation + Accessibility)
- Smoke tests that exercise delete/Photos flags on a disposable user

---

## Later / explore

- Notarized hotkey app (fewer Gatekeeper prompts)
- HDR-aware share presets (when/if tooling allows clearer control)
- Shortcuts / URL scheme triggers
- Multi-Mac documented fleet install

Out of scope unless demand is strong: Windows/Linux, replacing Preview with a custom editor, cloud upload backends, telemetry.

---

## Request a feature

1. Search [existing issues](https://github.com/travisjneuman/macos-screenshot-pipeline/issues) so we can stack-rank duplicates.  
2. Open a new issue with the **Feature request** template (or a clear title + problem + ideal behavior).  
3. Tag or title with the area when you can: `config`, `clipboard`, `photos`, `hotkey`, `staging`, `installer`.

Pull requests that match this roadmap and [CONTRIBUTING.md](../CONTRIBUTING.md) are welcome. Small, focused changes land faster than kitchen-sink rewrites.

---

## Maintainers

When shipping a roadmap item, update [BEHAVIOR.md](BEHAVIOR.md) in the same change if runtime behavior moves.
