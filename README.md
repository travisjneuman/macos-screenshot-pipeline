<div align="center">

# macos-screenshot-pipeline

### Stock macOS capture. Finished handoff.

**Staging first. Original into Photos. Then PNG on the clipboard. Markup in Preview.**  
No paid app. No Electron. No telemetry. No Desktop landfill.

[![License: MIT](https://img.shields.io/badge/license-MIT-0B6E4F?style=for-the-badge)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-native-000000?style=for-the-badge&logo=apple&logoColor=white)](#requirements)
[![launchd](https://img.shields.io/badge/idle-WatchPaths-1B4965?style=for-the-badge)](#how-it-works)
[![HDR honest](https://img.shields.io/badge/HDR-dual--path-5C4D7A?style=for-the-badge)](#design-honesty)

<br/>

![Hero](docs/assets/hero.png)

```text
  Cmd+Shift+4   →   staging  →  Photos (original)  →  clipboard PNG  →  cleanup
  Cmd+Shift+E   →   Preview markup  →  paste anywhere
```

![Demo](docs/assets/demo.gif)

<sub>MIT · Travis J. Neuman · v0.1.0</sub>

</div>

```mermaid
flowchart LR
  K["Cmd+Shift+3 / 4 / 5"] --> S["staging file"]
  S --> H["Photos — original / HDR"]
  H --> P["clipboard — PNG"]
  P --> D["delete staging"]
```

```mermaid
flowchart LR
  E["Cmd+Shift+E"] --> V["Preview markup"] --> C["Cmd+A · Cmd+C · Cmd+V"]
```

---

## Why this exists

Apple’s Screenshot app still forces tradeoffs:

| You want | Stock macOS | **This** |
|:---------|:------------|:---------|
| **HDR** archive on XDR | HEIC when HDR is on | Photos keeps **original bytes** |
| **Paste** into Discord / browsers / chat | Separate shortcut *or* file | **Automatic real PNG** every time |
| **Photos** library archive | Manual import | **Automatic** import + caption (iCloud only if you already use iCloud Photos) |
| **Clean Desktop** | Default dumping ground | Ephemeral **staging** only |
| **Fast markup** | Thumbnail bubble or scavenger hunt | **`⌘⇧E`** → Preview |
| **Idle CPU** | — | Capture agent **exits**; no poll loop |

Paid suites solve adjacent problems. This is the **thin native layer** on top of shortcuts you already use.

---

## Design honesty

> One file is **not** “full HDR screenshot” **and** “universal lossless PNG.”  
> Anyone who says otherwise is selling something or confused.

| Path | What you get | Why |
|:-----|:-------------|:----|
| **Archive** → Photos | System original (often **HEIC/HEIF** when HDR is on; name may still end in `.png`) | Best practical dynamic range in Apple’s stack |
| **Share** → clipboard | **True PNG** via `sips` | Discord, Chromium, non-Apple apps |

Clipboard PNG is typically an **SDR tone-map** of HDR content. That is the correct tradeoff for “paste cleanly everywhere.”

`defaults write com.apple.screencapture type png` is a **preference**, not a guarantee under HDR.

```mermaid
flowchart TB
  SC["screencapture writes staging<br/>HDR on — original bytes"]
  SC --> PH["1 · Photos import<br/>original / often HEIF"]
  PH --> CB["2 · sips → true PNG<br/>clipboard PNGf"]
  CB --> RM["3 · delete staging file"]
```

---

## Install

**About two minutes** if Xcode CLT is already present.

```bash
git clone https://github.com/travisjneuman/macos-screenshot-pipeline.git
cd macos-screenshot-pipeline
./install.sh
```

### First-run checklist

| # | Action |
|:-:|:-------|
| 1 | **System Settings → Privacy & Security → Accessibility** → enable **Screenshot Pipeline Hotkey** |
| 2 | Optional deep link: `open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"` |
| 3 | **⌘⇧4** → **⌘V** (Notes is a good first target) |
| 4 | Allow **Photos** automation if macOS prompts |
| 5 | **⌘⇧E** → markup → **⌘A** **⌘C** → **⌘V** |

### Installer flags

```bash
./install.sh --help
./install.sh --no-hotkey                 # capture path only
./install.sh --no-photos                 # clipboard only; keeps staging by default
./install.sh --keep-staging              # never delete staging after success
./install.sh --staging ~/Pictures/Screenshots
./install.sh --caption "Screen shot"
./install.sh --skip-prefs                # scripts/agents only
```

Config lands at:

```text
~/.config/macos-screenshot-pipeline/config.env
```

### Uninstall

```bash
./uninstall.sh                              # stop agents
./uninstall.sh --restore-stock-screenshots  # Desktop + thumbnail back
./uninstall.sh --purge                      # remove scripts/config/apps
```

Photos library content is **never** deleted.

---

## How it works

| Step | What actually happens |
|:----:|:----------------------|
| 1 | Installer points `com.apple.screencapture` **location** at staging (default `~/Pictures/Camera Roll`), sets **HDR on**, **floating thumbnail off** |
| 2 | You use stock **Cmd+Shift+3/4/5**. macOS writes the capture **into staging** (this tool does not capture) |
| 3 | `launchd` **WatchPaths** starts `process.sh` when staging changes; the job **exits** when done (no poll loop) |
| 4 | `process.sh`, per image: wait until size stable → **import original into Photos** (if enabled) → **PNG onto clipboard** → **delete staging** only when cleanup rules allow |
| 5 | Optional hotkey app: **Cmd+Shift+E** opens the **current clipboard image** in Preview (markup toolbar best-effort) |

### Capture pipeline order (default install)

```text
screencapture  →  staging file
               →  Photos.app import (original bytes; caption/keyword)
               →  clipboard PNG (sips tone-map/convert)
               →  delete staging file
```

| Mode | Photos | Clipboard PNG | Delete staging |
|:-----|:------:|:-------------:|:---------------|
| Default | Yes | Yes (after Photos attempt) | Yes, if Photos succeeded |
| `--no-photos` / `IMPORT_PHOTOS=0` | No | Yes | No by default (`DELETE_STAGING_ON_SUCCESS=0`) |
| `--keep-staging` / `DELETE_STAGING_ON_SUCCESS=0` | Per config | Yes | No |
| Photos import fails | Failed | Still attempted | **No** (file retained for retry) |

**Photos vs iCloud:** the script imports into the local **Photos** library via Automation. It does not talk to iCloud itself. If iCloud Photos is enabled in System Settings, Apple may sync that library afterward.

Deep dive: **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** · behavior contract: **[docs/BEHAVIOR.md](docs/BEHAVIOR.md)**

---

## Requirements

| Need | Notes |
|:-----|:------|
| macOS + GUI session | LaunchAgents + TCC dialogs |
| **Photos** + **Preview** | Photos optional with `--no-photos` |
| **Xcode CLT** (`swiftc`) | Hotkey build — or `--no-hotkey` |
| **Accessibility** | Global ⌘⇧E |
| **Automation → Photos** | Import + caption |

**Full Disk Access is not required.** This project opens no network connections of its own (Photos/iCloud sync is Apple’s stack if you enabled it).

---

## Permissions

| Permission | Why |
|:-----------|:----|
| Automation → Photos | Import + caption / keyword |
| Accessibility → Screenshot Pipeline Hotkey | Global hotkey + optional markup toolbar |

---

## Compare

| | **This** | CleanShot X | Shottr | `defaults` one-liners |
|:--|:---------|:------------|:-------|:---------------------|
| Cost | **Free (MIT)** | Paid | Freemium | Free |
| Photos-native archive | **Yes** | Different model | No | No |
| HDR story | **Documented dual-path** | Productized | Markup-first | Format only |
| Dependencies | macOS + CLT | App | App | None |
| Markup | Preview | Built-in | Built-in | Manual |
| Idle model | WatchPaths | App-dependent | App-dependent | N/A |

---

## Docs

| Doc | What’s inside |
|:----|:--------------|
| [USER-GUIDE](docs/USER-GUIDE.md) | Daily loops, disable/reenable |
| [BEHAVIOR](docs/BEHAVIOR.md) | **Authoritative** what the code does today |
| [ARCHITECTURE](docs/ARCHITECTURE.md) | Data flow, dual-path, resources, TCC |
| [INSTALL](docs/INSTALL.md) | Flags, layout, legacy migration |
| [OPERATIONS](docs/OPERATIONS.md) | Health checks, logs, restart |
| [TROUBLESHOOTING](docs/TROUBLESHOOTING.md) | Symptom → fix |
| [REFERENCE](docs/REFERENCE.md) | Paths, labels, env, log lines |
| [TEST-MATRIX](docs/TEST-MATRIX.md) | Manual acceptance checklist |
| [SECURITY](SECURITY.md) | Threat model / reporting |
| [ROADMAP](docs/ROADMAP.md) | Planned customization and how to request features |
| [GitHub About copy](docs/GITHUB-ABOUT.md) | Description, topics, social blurb |

**Want a change?** Open a [feature request](https://github.com/travisjneuman/macos-screenshot-pipeline/issues/new?labels=enhancement&template=feature_request.md) or discussion on the repo — preferences, clipboard formats, Photos on/off, staging paths, hotkeys, and more are on the [roadmap](docs/ROADMAP.md).

```bash
./scripts/smoke-test.sh    # static checks + optional swiftc
```

---

## FAQ

<details>
<summary><strong>Does ⌘⌃⇧4 (clipboard-only) use this pipeline?</strong></summary>

No. That shortcut never writes a staging file. Use **⌘⇧3 / ⌘⇧4 / ⌘⇧5** for clipboard **and** Photos.

</details>

<details>
<summary><strong>Why is staging empty after a shot?</strong></summary>

On the default success path the file is removed **after** a successful Photos import **and** the clipboard PNG step. Check **Photos → Recents** and `~/Library/Logs/macos-screenshot-pipeline.log` for `photos: imported`, then `clipboard: PNG ready`, then `cleanup: removed staging`.

</details>

<details>
<summary><strong>Finder shows HEIC / a weird preview — is it broken?</strong></summary>

Usually **HDR archive**. Expected. Pasteboard is still a real PNG.

</details>

<details>
<summary><strong>Can I remap ⌘⇧E?</strong></summary>

Not in v0.1 (fixed in the Swift agent). Follow-up territory.

</details>

<details>
<summary><strong>Google Photos doesn’t show my caption?</strong></summary>

Caption is set in Apple Photos (`description` / IPTC). Google’s mapping is best-effort and outside this tool.

</details>

<details>
<summary><strong>Will this fight another screenshot tool?</strong></summary>

If something else also watches the same staging folder or steals **⌘⇧E**, pick one owner. Installer unloads known legacy labels from the private precursor setup.

</details>

---

## Project principles

```text
✓  Native tools only     launchd · sips · osascript · Photos · Preview
✓  Idle-free capture     WatchPaths; process starts, works, exits
✓  Fail safe             Photos fail → staging retained
✓  Honest formats        HDR archive ≠ PNG paste — documented
✓  No telemetry          No network from this codebase
✓  Removable             uninstall agents; optional stock prefs restore
```

---

## License

[MIT](LICENSE) © [Travis J. Neuman](https://github.com/travisjneuman)

**v0.1.0** — production-proven behavior, public packaging. Issues and PRs welcome.

---

<div align="center">

```text
Cmd+Shift+4 then paste.   Cmd+Shift+E to mark up.
```

<sub>Name is utilitarian on purpose. The workflow shouldn’t be.</sub>

</div>
