import AppKit
import Carbon.HIToolbox
import IOKit.hid

enum KeystrokePermission {
    static var isGranted: Bool {
        if AXIsProcessTrusted() { return true }
        return IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    static func request() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
        IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
    }

    static func openSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
}

final class ShortcutManager {
    var onTrigger: ((String) -> Void)?
    var onNothingCopied: (() -> Void)?
    // report conflicts instead of silently accepting an unavailable shortcut
    var onUnavailable: ((OSStatus) -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    private var current: ShortcutSpec?
    private var lastPress: TimeInterval?
    private var pasteboardCountBeforeCopy: Int = 0

    private static let signature: OSType = 0x6D636C74  // 'mclt'

    func apply(_ spec: ShortcutSpec) {
        guard spec != current else { return }
        current = spec
        teardown()
        lastPress = nil

        if spec.isCommandC {
            installMonitors()
        } else {
            installHotKey(spec)
        }
    }

    func teardown() {
        [globalMonitor, localMonitor].forEach { if let monitor = $0 { NSEvent.removeMonitor(monitor) } }
        globalMonitor = nil
        localMonitor = nil

        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        if let handlerRef { RemoveEventHandler(handlerRef) }
        handlerRef = nil
    }

    deinit { teardown() }

    private func installMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleObserved(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.handleObserved(event)
            return event
        }
    }

    private func handleObserved(_ event: NSEvent) {
        guard let spec = current, spec.matches(event) else { return }
        // event timestamps are monotonic
        register(press: event.timestamp, spec: spec)
    }

    private func installHotKey(_ spec: ShortcutSpec) {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            Unmanaged<ShortcutManager>.fromOpaque(userData).takeUnretainedValue().handleHotKey()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &handlerRef)

        let identifier = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(UInt32(spec.keyCode), spec.carbonModifiers,
                                         identifier, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr || hotKeyRef == nil { onUnavailable?(status) }
    }

    private func handleHotKey() {
        guard let spec = current else { return }
        register(press: ProcessInfo.processInfo.systemUptime, spec: spec)
    }

    private func register(press now: TimeInterval, spec: ShortcutSpec) {
        guard spec.isDoublePress else {
            pasteboardCountBeforeCopy = NSPasteboard.general.changeCount
            trigger(spec)
            return
        }

        if let previous = lastPress, now - previous <= Constants.doublePressInterval {
            lastPress = nil
            trigger(spec)
        } else {
            lastPress = now
            pasteboardCountBeforeCopy = NSPasteboard.general.changeCount
        }
    }

    private func trigger(_ spec: ShortcutSpec) {
        let pressBaseline = pasteboardCountBeforeCopy
        let needsSyntheticCopy = !spec.isCommandC

        Task { @MainActor in
            // read the baseline immediately before posting the synthetic copy
            let baseline: Int
            if needsSyntheticCopy {
                baseline = NSPasteboard.general.changeCount
                Self.synthesizeCopy()
            } else {
                baseline = pressBaseline
            }

            // never send stale clipboard content when this copy did not complete
            let pasteboard = NSPasteboard.general
            let deadline = Date().addingTimeInterval(0.5)
            while pasteboard.changeCount == baseline && Date() < deadline {
                try? await Task.sleep(nanoseconds: 20_000_000)
            }
            guard pasteboard.changeCount != baseline else {
                onNothingCopied?()
                return
            }

            guard let text = pasteboard.string(forType: .string),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                onNothingCopied?()
                return
            }
            onTrigger?(text)
        }
    }

    private static func synthesizeCopy() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_C)

        guard let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        else { return }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}
