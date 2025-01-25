import Cocoa
import Carbon.HIToolbox

class ShortcutManager {
    private var shortcutMonitor: Any?
    var shortcutHandler: (() -> Void)?
    
    func registerGlobalShortcut() {
        NSEvent.addGlobalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            // Control + T
            if event.modifierFlags.contains(.control) &&
               event.keyCode == kVK_ANSI_T {
                self?.shortcutHandler?()
            }
        }
    }
}
