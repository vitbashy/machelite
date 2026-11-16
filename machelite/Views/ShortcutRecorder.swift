import SwiftUI
import Carbon.HIToolbox

struct ShortcutField: View {
    @Binding var spec: ShortcutSpec
    @Environment(\.theme) private var theme

    @State private var isRecording = false
    @State private var preview: ShortcutSpec?

    private var caption: String {
        if let preview { return preview.display }
        return isRecording ? "Type a shortcut…" : spec.display
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(theme.controlFillCompact)
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(isRecording ? Color.accentColor : theme.hairline,
                                  lineWidth: isRecording ? 2 : 1)

                Text(caption)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isRecording && preview == nil ? .secondary : .primary)
                    .lineLimit(1)

                ShortcutCapture(isRecording: $isRecording, preview: $preview, spec: $spec)
            }
            .frame(width: 148, height: 28)

            Button {
                spec = .default
                preview = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .medium))
                    .frame(width: 28, height: 28)
                    .background(theme.controlFillCompact, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.hairline, lineWidth: 0.7))
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.primaryText)
            .accessibilityLabel("Reset shortcut")
            .help("Reset to \(ShortcutSpec.default.display)")
            .disabled(spec == .default)
        }
    }
}

private struct ShortcutCapture: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var preview: ShortcutSpec?
    @Binding var spec: ShortcutSpec

    func makeNSView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onRecordingChange = { isRecording = $0 }
        view.onPreview = { preview = $0 }
        view.onCommit = { spec = $0; preview = nil }
        return view
    }

    func updateNSView(_ nsView: CaptureView, context: Context) {}
}

final class CaptureView: NSView {
    var onRecordingChange: ((Bool) -> Void)?
    var onPreview: ((ShortcutSpec?) -> Void)?
    var onCommit: ((ShortcutSpec) -> Void)?

    private var pending: ShortcutSpec?
    private var pendingTimer: Timer?

    private var isRecording = false {
        didSet { onRecordingChange?(isRecording) }
    }

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        pending = nil
        onPreview?(nil)
    }

    override func becomeFirstResponder() -> Bool {
        isRecording = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        finishPending()
        isRecording = false
        return true
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else { return false }
        capture(event)
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        capture(event)
    }

    private func capture(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.relevant)

        if event.keyCode == UInt16(kVK_Escape) && flags.isEmpty {
            cancel()
            return
        }
        guard ShortcutSpec.isUsable(keyCode: event.keyCode, flags: flags) else {
            NSSound.beep()
            return
        }

        let candidate = ShortcutSpec(keyCode: event.keyCode,
                                     modifiers: flags.rawValue,
                                     isDoublePress: false)

        if let pending, pending.keyCode == candidate.keyCode,
           pending.modifiers == candidate.modifiers {
            pendingTimer?.invalidate()
            pendingTimer = nil
            self.pending = nil
            commit(ShortcutSpec(keyCode: candidate.keyCode,
                                modifiers: candidate.modifiers,
                                isDoublePress: true))
            return
        }

        pending = candidate
        onPreview?(candidate)
        pendingTimer?.invalidate()
        pendingTimer = Timer.scheduledTimer(withTimeInterval: Constants.doublePressInterval,
                                            repeats: false) { [weak self] _ in
            self?.finishPending()
        }
    }

    private func finishPending() {
        pendingTimer?.invalidate()
        pendingTimer = nil
        guard let pending else { return }
        self.pending = nil
        commit(pending)
    }

    private func commit(_ spec: ShortcutSpec) {
        onCommit?(spec)
        isRecording = false
        window?.makeFirstResponder(nil)
    }

    private func cancel() {
        pendingTimer?.invalidate()
        pendingTimer = nil
        pending = nil
        onPreview?(nil)
        isRecording = false
        window?.makeFirstResponder(nil)
    }

    deinit { pendingTimer?.invalidate() }
}
