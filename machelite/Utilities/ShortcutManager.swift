import Carbon
import AppKit

class ShortcutManager {
   private var globalShortcutMonitor: Any?
   private var lastKeyPressTime: Date?
   private static let doublePressInterval = 0.3 // seconds
   var shortcutHandler: (() -> Void)?
   
   func registerGlobalShortcut() {
       print("Registering global shortcut")
       globalShortcutMonitor = NSEvent.addGlobalMonitorForEvents(
           matching: .keyDown
       ) { [weak self] event in
           print("Key pressed: \(event.keyCode)")
           if event.modifierFlags.contains(.command) && event.keyCode == kVK_ANSI_C {
               self?.handleKeyPress()
           }
       }
   }
   
    private func handleKeyPress() {
        let now = Date()
        print("Press time: \(now)")
        if let lastPress = lastKeyPressTime {
            let interval = now.timeIntervalSince(lastPress)
            print("Interval: \(interval)")
            if interval < Self.doublePressInterval {
                print("Triggering handler")
                DispatchQueue.main.async {
                    self.shortcutHandler?()
                }
            }
        }
        lastKeyPressTime = now
    }
   
   deinit {
       if let monitor = globalShortcutMonitor {
           NSEvent.removeMonitor(monitor)
       }
   }
}
