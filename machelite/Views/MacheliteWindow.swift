import AppKit

final class MacheliteWindow: NSWindow, NSWindowDelegate {
    // hosting layout can overwrite AppKit size hints
    private var enforcedMinimumSize: NSSize = .zero

    func enforceMinimumContentSize(_ size: NSSize) {
        enforcedMinimumSize = frameRect(forContentRect: NSRect(origin: .zero, size: size)).size
        contentMinSize = size
        minSize = enforcedMinimumSize
        delegate = self
        setFrame(frame, display: false)
    }

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        NSSize(width: max(frameSize.width, enforcedMinimumSize.width),
               height: max(frameSize.height, enforcedMinimumSize.height))
    }

    private func constrainedFrame(_ requested: NSRect) -> NSRect {
        var result = requested
        result.size = windowWillResize(self, to: requested.size)
        // preserve the top edge while restoring the minimum size
        result.origin.y = requested.maxY - result.height
        return result
    }

    override func layoutIfNeeded() {
        super.layoutIfNeeded()
        alignTitlebarButtons()
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(constrainedFrame(frameRect), display: flag)
        alignTitlebarButtons()
    }

    override func setFrame(_ frameRect: NSRect, display flag: Bool, animate: Bool) {
        super.setFrame(constrainedFrame(frameRect), display: flag, animate: animate)
        alignTitlebarButtons()
    }

    override func makeKeyAndOrderFront(_ sender: Any?) {
        super.makeKeyAndOrderFront(sender)
        alignTitlebarButtons()
    }

    private func alignTitlebarButtons() {
        guard let parent = standardWindowButton(.closeButton)?.superview else { return }
        let height = Constants.titlebarInset
        // keep repositioned traffic lights inside their native host
        if parent.frame.height < height {
            var rect = parent.frame
            rect.origin.y -= height - rect.height
            rect.size.height = height
            parent.frame = rect
        }
        let center = parent.convert(NSPoint(x: 0, y: frame.height - height / 2), from: nil)
        for (index, kind) in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].enumerated() {
            guard let button = standardWindowButton(kind) else { continue }
            let horizontal = parent.convert(NSPoint(x: Constants.trafficLightLeadingCenter + CGFloat(index) * 23,
                                                    y: frame.height - height / 2), from: nil)
            button.setFrameOrigin(NSPoint(x: horizontal.x - button.frame.width / 2,
                                          y: center.y - button.frame.height / 2))
        }
    }
}
