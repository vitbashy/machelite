import AppKit
import Carbon.HIToolbox

struct ShortcutSpec: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt
    var isDoublePress: Bool

    static let `default` = ShortcutSpec(keyCode: UInt16(kVK_ANSI_C),
                                        modifiers: NSEvent.ModifierFlags.command.rawValue,
                                        isDoublePress: true)

    var flags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers).intersection(.relevant)
    }

    var isCommandC: Bool {
        keyCode == UInt16(kVK_ANSI_C) && flags == .command
    }

    // every shortcut needs Accessibility, for one of two reasons: a command-c shortcut must observe keystrokes (a registered hot key would swallow the event and stop command-c copying at all), and every other shortcut posts a synthetic command-c, which also requires a trusted process
    var needsKeystrokePermission: Bool { true }

    var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        if flags.contains(.shift)   { mask |= UInt32(shiftKey) }
        if flags.contains(.option)  { mask |= UInt32(optionKey) }
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        return mask
    }

    func matches(_ event: NSEvent) -> Bool {
        event.keyCode == keyCode
            && event.modifierFlags.intersection(.relevant) == flags
    }

    var display: String {
        let key = KeyNames.name(for: keyCode)
        var text = ""
        if flags.contains(.control) { text += "⌃" }
        if flags.contains(.option)  { text += "⌥" }
        if flags.contains(.shift)   { text += "⇧" }
        if flags.contains(.command) { text += "⌘" }
        text += key
        if isDoublePress {
            text += key.count == 1 ? key : " ×2"
        }
        return text
    }

    static func isUsable(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        if KeyNames.functionKeys[keyCode] != nil { return true }
        return flags.contains(.command) || flags.contains(.control) || flags.contains(.option)
    }
}

extension NSEvent.ModifierFlags {
    static let relevant: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
}

enum KeyNames {
    // function keys are usable without a modifier, so they are listed once here and their labels derived rather than repeated in `fixed`.
    static let functionKeys: [UInt16: String] = [
        UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
        UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
        UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
        UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
    ]

    private static let fixed: [UInt16: String] = [
        UInt16(kVK_Space): "Space",
        UInt16(kVK_Return): "↩",
        UInt16(kVK_Tab): "⇥",
        UInt16(kVK_Delete): "⌫",
        UInt16(kVK_ForwardDelete): "⌦",
        UInt16(kVK_Escape): "⎋",
        UInt16(kVK_LeftArrow): "←",
        UInt16(kVK_RightArrow): "→",
        UInt16(kVK_UpArrow): "↑",
        UInt16(kVK_DownArrow): "↓",
        UInt16(kVK_Home): "↖",
        UInt16(kVK_End): "↘",
        UInt16(kVK_PageUp): "⇞",
        UInt16(kVK_PageDown): "⇟",
    ]

    // translations are cached per key code and dropped when the input source changes, so a shortcut label costs one Carbon call rather than one per view evaluation
    private static let cache = LayoutCache()

    private final class LayoutCache: @unchecked Sendable {
        private var entries: [UInt16: String] = [:]
        private let lock = NSLock()

        init() {
            DistributedNotificationCenter.default().addObserver(
                forName: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
                object: nil, queue: nil) { [weak self] _ in self?.clear() }
        }

        func clear() {
            lock.lock(); entries.removeAll(); lock.unlock()
        }

        func label(for keyCode: UInt16, compute: (UInt16) -> String) -> String {
            lock.lock()
            if let hit = entries[keyCode] { lock.unlock(); return hit }
            lock.unlock()
            let value = compute(keyCode)
            lock.lock(); entries[keyCode] = value; lock.unlock()
            return value
        }
    }

    // reads the character off the ASCII-capable layout rather than the active one
    static func name(for keyCode: UInt16) -> String {
        if let known = fixed[keyCode] { return known }
        if let known = functionKeys[keyCode] { return known }
        return cache.label(for: keyCode, compute: translate)
    }

    private static func translate(_ keyCode: UInt16) -> String {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData)
        else { return "Key \(keyCode)" }

        let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
        return data.withUnsafeBytes { buffer -> String in
            guard let layout = buffer.bindMemory(to: UCKeyboardLayout.self).baseAddress else {
                return "Key \(keyCode)"
            }
            var deadKeyState: UInt32 = 0
            var characters = [UniChar](repeating: 0, count: 4)
            var length = 0
            let status = UCKeyTranslate(layout, keyCode, UInt16(kUCKeyActionDisplay), 0,
                                        UInt32(LMGetKbdType()),
                                        OptionBits(kUCKeyTranslateNoDeadKeysBit),
                                        &deadKeyState, characters.count, &length, &characters)
            guard status == noErr, length > 0 else { return "Key \(keyCode)" }
            return String(utf16CodeUnits: characters, count: length).uppercased()
        }
    }
}
