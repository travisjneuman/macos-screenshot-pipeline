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
  │    ├─ show-thumbnail true → set false; killall SystemUIServer
  │    └─ 5K/6K or multi-display capture → keep CLIPBOARD_MAX_DIMENSION=3840
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
| Paste empty; `sips conversion failed` | Partial/exotic file | Re-capture; `file` on staging |
| Paste empty; `PNG ready` | Target app | Try Notes |
| Photos empty; import failed | Automation denied | Privacy → Automation → Photos |
| Staging remains | Photos failed, or delete disabled | By design; fix Photos / config; clipboard may still have worked |
| Desktop screenshots | Pref reset | Re-apply prefs |
| Slow every shot | Floating thumbnail | `show-thumbnail -bool false` |
| Slow large/full-screen shots | macOS may render a scaled 4K display at 5K/6K; PNG work scales with pixels | Use the default 3840px clipboard ceiling; originals in Photos are unchanged |
| Several displays captured | Each display creates work; clipboard ends with the last processed image | Prefer selection/window capture when only one screen is needed |
| HEIC in Finder | HDR | Expected archive form |
| ⌘⇧E silent | Agent / Accessibility | `launchctl print`; Settings |
| Lock exit code 75 | Another worker holds the native lock | Let the active worker finish; do not remove its lock file |
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

## Worker lock

The native kernel lock releases when its worker exits, including crashes. The empty `~/.local/state/macos-screenshot-pipeline/process.lock` file normally remains. Do not delete it while a worker is running: replacing its inode can allow overlapping workers. The older `process.lock.d` directory is no longer used by current code.

## Photos reopens after automatic quit

Check `launchctl list` for both `com.travisjneuman.screenshotpipeline.capture` and legacy `dev.neuman.screenshot-to-photos`. Two workers can import the same screenshot, overwrite the clipboard, and reopen Photos after the current worker quits it. The installer now persistently disables the legacy capture job (and legacy hotkey when the replacement hotkey is enabled), then unloads it. `bootout` alone does not prevent the old plist loading at the next login. Existing legacy scripts/plists are preserved. To intentionally restore the old pipeline, first unload the current job, then use `launchctl enable` and `bootstrap` for the legacy job; never run both against the same staging directory.
