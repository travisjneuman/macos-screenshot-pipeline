# Contributing

Thanks for improving **macos-screenshot-pipeline**.

## Feature requests

Open a GitHub issue with the **Feature request** template. Check [docs/ROADMAP.md](docs/ROADMAP.md) first — many toggles (Photos off, staging path, keep staging) already exist in v0.1; say if those are insufficient and why.

## Ground rules

- Keep the stack **native**: bash, Swift, `sips`, `osascript`, `launchd`, `defaults`.
- No Electron, no mandatory Homebrew runtime deps, no telemetry.
- Do not claim “lossless HDR PNG” — document the dual-path model honestly.
- Prefer small, reviewable PRs.

## Development

```bash
git clone https://github.com/travisjneuman/macos-screenshot-pipeline.git
cd macos-screenshot-pipeline
./scripts/smoke-test.sh
# On a throwaway macOS user (recommended before behavioral changes):
./install.sh --no-photos   # or full install
```

Avoid installing the public agents on a machine that already runs a private fork against the **same** staging directory without unloading one of them first. `install.sh` unloads known legacy labels (`dev.neuman.screenshot-*`).

## Style

- Bash: `set -euo pipefail` where appropriate; comment intentional exceptions.
- Swift: minimal, no package manager for MVP.
- Comments explain **why**.

## Commit messages

Conventional Commits preferred (`feat:`, `fix:`, `docs:`, `chore:`).

## Docs accuracy

Runtime behavior is defined in [docs/BEHAVIOR.md](docs/BEHAVIOR.md). Update it in the same PR when `process.sh` or installer semantics change. Do not put internal production notes or private host details in public docs.

## License

By contributing, you agree your contributions are licensed under the MIT License.
