#!/bin/bash
# Static (and lightly dynamic) checks — no LaunchAgent install required.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
fail=0

ok() { printf '  OK  %s\n' "$*"; }
bad() { printf '  FAIL %s\n' "$*"; fail=1; }

echo "== smoke-test: macos-screenshot-pipeline =="

need=(
  README.md LICENSE CHANGELOG.md CONTRIBUTING.md SECURITY.md
  install.sh uninstall.sh
  bin/process.sh bin/edit-clipboard-in-preview.sh
  bin/hotkey-agent.swift bin/apply-screencapture-prefs.sh
  launchagents/com.travisjneuman.screenshotpipeline.capture.plist
  launchagents/com.travisjneuman.screenshotpipeline.hotkey.plist
  docs/ARCHITECTURE.md docs/USER-GUIDE.md docs/INSTALL.md
  docs/OPERATIONS.md docs/TROUBLESHOOTING.md docs/REFERENCE.md
  docs/TEST-MATRIX.md docs/GITHUB-ABOUT.md docs/BEHAVIOR.md docs/ROADMAP.md
)

for f in "${need[@]}"; do
  if [[ -f "$f" ]]; then ok "exists $f"; else bad "missing $f"; fi
done

for s in install.sh uninstall.sh bin/process.sh bin/edit-clipboard-in-preview.sh \
         bin/apply-screencapture-prefs.sh scripts/smoke-test.sh; do
  if bash -n "$s" 2>/dev/null; then ok "bash -n $s"; else bad "bash -n $s"; fi
done

# Docs may mention private history; product code must not hardcode a host home.
hits="$(grep -R --line-number -E '/Users/tjn' \
  bin launchagents install.sh uninstall.sh 2>/dev/null || true)"
if [[ -n "$hits" ]]; then
  printf '%s\n' "$hits"
  bad "host path in code/install paths"
else
  ok "code/install free of host-absolute home paths"
fi

if grep -q '__HOME__' launchagents/*.plist \
  && grep -q '__STAGING__' launchagents/com.travisjneuman.screenshotpipeline.capture.plist; then
  ok "plist templates use placeholders"
else
  bad "plist placeholders missing"
fi

if grep -q 'com.travisjneuman.screenshotpipeline' install.sh; then
  ok "public launchd namespace in install.sh"
else
  bad "public namespace missing from install.sh"
fi

if grep -qi 'HDR' README.md && grep -qi 'PNG' README.md; then
  ok "README mentions HDR and PNG"
else
  bad "README honesty section incomplete"
fi

if command -v swiftc >/dev/null 2>&1; then
  tmp="$(mktemp -t msp-hotkey)"
  if swiftc -O -o "$tmp" bin/hotkey-agent.swift 2>/dev/null; then
    ok "swiftc hotkey-agent.swift"
  else
    bad "swiftc hotkey-agent.swift"
  fi
  rm -f "$tmp"
else
  ok "swiftc absent — skip compile (install --no-hotkey still valid)"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "== FAILED =="
  exit 1
fi
echo "== ALL PASSED =="
exit 0
