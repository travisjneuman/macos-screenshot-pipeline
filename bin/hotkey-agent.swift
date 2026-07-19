import Cocoa
import Carbon

// ⌘⇧E → edit-clipboard-in-preview.sh
// Carbon RegisterEventHotKey — event-driven, no polling. Needs Accessibility once.

let scriptPath = NSString(
  string: "~/.local/libexec/macos-screenshot-pipeline/edit-clipboard-in-preview.sh"
).expandingTildeInPath

func runEditScript() {
  let task = Process()
  task.executableURL = URL(fileURLWithPath: "/bin/bash")
  task.arguments = [scriptPath]
  task.standardOutput = FileHandle.nullDevice
  task.standardError = FileHandle.nullDevice
  do { try task.run() }
  catch { NSLog("screenshot-pipeline-hotkey: run failed: \(error)") }
}

func hotKeyHandler(
  nextHandler: EventHandlerCallRef?,
  theEvent: EventRef?,
  userData: UnsafeMutableRawPointer?
) -> OSStatus {
  var hotKeyID = EventHotKeyID()
  GetEventParameter(
    theEvent,
    EventParamName(kEventParamDirectObject),
    EventParamType(typeEventHotKeyID),
    nil,
    MemoryLayout<EventHotKeyID>.size,
    nil,
    &hotKeyID
  )
  if hotKeyID.id == 1 {
    DispatchQueue.main.async { runEditScript() }
  }
  return noErr
}

func registerCmdShiftE() -> EventHotKeyRef? {
  var eventType = EventTypeSpec(
    eventClass: OSType(kEventClassKeyboard),
    eventKind: UInt32(kEventHotKeyPressed)
  )
  var handlerRef: EventHandlerRef?
  InstallEventHandler(
    GetApplicationEventTarget(),
    hotKeyHandler,
    1,
    &eventType,
    nil,
    &handlerRef
  )

  // keyCode 14 = E; cmdKey + shiftKey
  var hotKeyRef: EventHotKeyRef?
  var hotKeyID = EventHotKeyID(signature: OSType(0x4D535031), id: 1) // 'MSP1'
  let status = RegisterEventHotKey(
    UInt32(kVK_ANSI_E),
    UInt32(cmdKey | shiftKey),
    hotKeyID,
    GetApplicationEventTarget(),
    0,
    &hotKeyRef
  )
  if status != noErr {
    NSLog("screenshot-pipeline-hotkey: RegisterEventHotKey failed: \(status)")
    return nil
  }
  NSLog("screenshot-pipeline-hotkey: registered Cmd+Shift+E")
  return hotKeyRef
}

class AppDelegate: NSObject, NSApplicationDelegate {
  var hotKey: EventHotKeyRef?

  func applicationDidFinishLaunching(_ notification: Notification) {
    hotKey = registerCmdShiftE()
  }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
