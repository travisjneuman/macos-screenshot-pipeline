# Troubleshooting

Work top-down: **prefs → agents → logs → TCC → rebuild**.

## Decision tree

```text
Symptom
  ├─ Paste empty after ⌘⇧4
  │    ├─ Log has "clipboard: PNG ready"? → try Notes; target may reject images
  │    ├─ Log silent? → capture agent / WatchPaths / location pref
  │    └─ sips/osascript failure → corrupt/partial file
  ├─ Photos missing shot
  │    ├─ "photos: imported"? → check Photos Recents; iCloud sync is separate/delayed
  │    ├─ "import failed"? → Automation TCC for Photos
  │    ├─ "photos: skipped"? → IMPORT_PHOTOS=0 / --no-photos
  │    └─ Staging retained? → fix Photos; re-run process.sh
  ├─ Files stuck in staging
  │    └─ Photos failure, or DELETE_STAGING_ON_SUCCESS=0 → fix import or config
  ├─ Desktop filling up
  │    └─ location pref wrong → re-run install or apply-screencapture-prefs
  ├─ 5–10s delay before paste
  │    └─ show-thumbnail true → set false; killall SystemUIServer
  ├─ ⌘⇧E does nothing
  │    ├─ Hotkey agent down → bootstrap
  │    ├─ Accessibility off → enable app
  │    └─ Chord stolen → quit conflicting app
  └─ Preview opens, no markup bar
       └─ ⇧⌘A; Accessibility for System Events automation
```

## Symptom matrix

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Paste empty; log silent | Agent unloaded / wrong location | Health check; reinstall |
| Paste empty; `sips failed` | Partial/exotic file | Re-capture; `file` on staging |
| Paste empty; `PNG ready` | Target app | Try Notes |
| Photos empty; import failed | Automation denied | Privacy → Automation → Photos |
| Staging remains | Photos failed, or delete disabled | By design; fix Photos / config; clipboard may still have worked |
| Desktop screenshots | Pref reset | Re-apply prefs |
| Slow every shot | Floating thumbnail | `show-thumbnail -bool false` |
| HEIC in Finder | HDR | Expected archive form |
| ⌘⇧E silent | Agent / Accessibility | `launchctl print`; Settings |
| Lock skip messages | Overlap | Wait; clear stale lock >2 min |
| RegisterEventHotKey failed | Conflict / double | Restart hotkey agent |

## Clipboard

```bash
ls -la ~/Pictures/Camera\ Roll/
~/.local/libexec/macos-screenshot-pipeline/process.sh
tail -20 ~/Library/Logs/macos-screenshot-pipeline.log
```

Remember: **⌘⌃⇧4** never hits this pipeline.

## Photos

1. Open Photos once (unlock library).  
2. Privacy & Security → **Automation** — allow control of Photos (the script host may appear as `osascript` / `bash` depending on macOS).  
3. Re-run `process.sh` on retained staging files.  
4. Remember: success here is **local Photos import**. iCloud appearance on other devices is not performed by this tool.

## Hotkey

```bash
launchctl print "gui/$(id -u)/com.travisjneuman.screenshotpipeline.hotkey" | head -40
tail -20 ~/Library/Logs/macos-screenshot-pipeline-hotkey.err.log
```

Re-approve **Screenshot Pipeline Hotkey** in Accessibility after every significant rebuild.

## Clear stale lock

```bash
rm -rf ~/.local/state/macos-screenshot-pipeline/process.lock.d
```

Only if no `process.sh` is running and the lock is stuck.
