import Cocoa
import SwiftUI

class PopoverManager {
    private var popover: NSPopover
    @State private var originalText: String = ""
    @State private var translatedText: String = ""
    
    init() {
        self.popover = NSPopover()
        setupPopover()
    }
    
    private func setupPopover() {
        popover.contentSize = NSSize(
            width: Constants.windowWidth,
            height: Constants.windowHeight
        )
        popover.behavior = .transient
        
        let contentView = TranslationView(
            originalText: .constant(originalText),
            translatedText: .constant(translatedText)
        )
        popover.contentViewController = NSHostingController(
            rootView: contentView
        )
    }
    
    func show(relativeTo rect: NSRect, of view: NSView) {
        popover.show(relativeTo: rect, of: view, preferredEdge: .maxY)
    }
    
    func updateOriginalText(_ text: String) {
        originalText = text
        updateView()
    }
    
    func updateTranslatedText(_ text: String) {
        translatedText = text
        updateView()
    }
    
    private func updateView() {
        let contentView = TranslationView(
            originalText: .constant(originalText),
            translatedText: .constant(translatedText)
        )
        popover.contentViewController = NSHostingController(
            rootView: contentView
        )
    }
}
