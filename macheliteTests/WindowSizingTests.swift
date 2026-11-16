import AppKit
import Testing
@testable import machelite

@MainActor
struct WindowSizingTests {
    @Test func minimumSurvivesChangedHostingHintsAndFrameUpdates() {
        let window = MacheliteWindow(
            contentRect: NSRect(origin: .zero, size: Constants.windowDefaultSize),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        window.enforceMinimumContentSize(Constants.windowMinSize)
        let minimum = window.minSize
        window.minSize = NSSize(width: 1, height: 1)
        let tiny = NSRect(x: 100, y: 100, width: 120, height: 200)
        window.setFrame(tiny, display: false)
        #expect(window.frame.width >= minimum.width)
        #expect(window.frame.height >= minimum.height)
        window.setFrame(tiny, display: false, animate: false)
        #expect(window.frame.width >= minimum.width)
        #expect(window.frame.height >= minimum.height)
        let dragSize = window.delegate?.windowWillResize?(window, to: tiny.size)
        #expect(dragSize == minimum)
    }
}
