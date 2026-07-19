# Security

## What this software does

- Reads screenshot files from a user-chosen **staging directory**.
- Writes a PNG to the **clipboard**.
- Optionally tells **Photos** to import those files (Automation).
- Optionally runs a small **global hotkey** app (Accessibility).

It does **not** require Full Disk Access, does not open network connections of its own, and does not phone home.

## Permissions

| Permission | Purpose |
|------------|---------|
| Automation → Photos | Import + caption |
| Accessibility → Screenshot Pipeline Hotkey | Global ⌘⇧E and optional Preview markup menu click |

## Reporting issues

If you believe you found a vulnerability in this repository, open a private security advisory on GitHub if available, or contact the maintainer via the email on their GitHub profile / commit history. Please do not file a public issue with exploit detail until a fix is available.

## Supply chain

- Prefer installing from a tagged release or a commit you trust.
- The hotkey app is **ad-hoc codesigned** by default (not Developer ID / notarized). macOS may show Gatekeeper/TCC prompts after rebuilds — that is expected.
