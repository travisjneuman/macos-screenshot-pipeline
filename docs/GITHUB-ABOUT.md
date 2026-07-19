# GitHub repository About + launch copy

Paste these into the GitHub UI when the public repo exists.  
Keep this file updated if the one-liner evolves.

---

## About → Description (≤350 chars; aim short)

**Primary (recommended):**

```text
Stock macOS screenshots → staging → Photos (original) → clipboard PNG + ⌘⇧E Preview markup. Native launchd pipeline. HDR-honest dual path. MIT.
```

**Shorter:**

```text
⌘⇧4 → staging → Photos original → paste PNG. ⌘⇧E → Preview markup. Native, idle-free, HDR-honest. MIT.
```

**Alternate (benefit-led):**

```text
Finish what stock Screenshot starts: staging file, Photos/iCloud archive, then clipboard PNG, Preview markup — no paid app.
```

---

## About → Website

Until a dedicated page exists:

- Leave empty, **or**
- Personal site project URL if you add one later  
- Optional: deep-link a blog post once written

Suggested future path: a short project page on your site with the same hero + demo GIF as the README.

---

## About → Topics

```text
macos
screenshot
photos
clipboard
launchd
hdr
preview
productivity
swift
shell
mit-license
```

Minimum useful set if GitHub limits feel noisy:

```text
macos
screenshot
photos
clipboard
launchd
hdr
productivity
```

---

## Social / announce blurb (X, Mastodon, blog)

```text
Open-sourced the macOS screenshot kit I actually run:

⌘⇧4 → staging → original into Photos → PNG on the clipboard
⌘⇧E → Preview markup
HDR left on — dual-path on purpose (archive ≠ paste format)
WatchPaths, not a polling daemon

https://github.com/travisjneuman/macos-screenshot-pipeline
```

---

## Repo README hero pin

The README is the homepage. When you have assets:

| Asset | Path | Notes |
|-------|------|-------|
| Demo GIF | `docs/assets/demo.gif` | 20–30s; dark desktop; show paste + Photos + markup |
| Optional static diagram PNG | `docs/assets/flow.png` | Only if GIF is delayed; SVG/PNG export of dual-path |

Recording checklist is commented in `README.md`.

---

## GitHub release `v0.1.0` text

```markdown
## macos-screenshot-pipeline v0.1.0

First public release of a production-proven native screenshot handoff for macOS.

### Highlights
- WatchPaths capture processor (idle = not running)
- Ordered dual path: original → Photos, then true PNG → clipboard
- ⌘⇧E → Preview markup via small Carbon hotkey app
- Config file + install flags (`--no-photos`, `--no-hotkey`, …)
- HDR-honest documentation (archive ≠ paste format)

### Install
```bash
git clone https://github.com/travisjneuman/macos-screenshot-pipeline.git
cd macos-screenshot-pipeline
./install.sh
```

MIT © Travis J. Neuman
```
