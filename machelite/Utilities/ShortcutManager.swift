import Cocoa
import Carbon.HIToolbox

class ShortcutManager {
    private var shortcutMonitor: Any?
    var shortcutHandler: (() -> Void)?
    
    func registerGlobalShortcut() {
        shortcutMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: .keyDown
        ) { [weak self] event in
            // Check for Control + Y
            if event.modifierFlags.contains(.control) &&
               event.keyCode == UInt16(kVK_ANSI_Y) {
                self?.shortcutHandler?()
            }
        }
    }
    
    deinit {
        if let monitor = shortcutMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
