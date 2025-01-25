import Cocoa
import SwiftUI

class PopoverManager: ObservableObject {
    private var popover: NSPopover
    @Published var originalText: String = ""
    @Published var translatedText: String = ""
    
    init() {
        self.popover = NSPopover()
        setupPopover()
    }
    
    private func setupPopover() {
        popover.contentSize = NSSize(width: Constants.windowWidth, height: Constants.windowHeight)
        popover.behavior = .transient
        updateView()
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
        popover.contentViewController = NSHostingController(
            rootView: TranslationView(
                originalText: .constant(originalText),
                translatedText: .constant(translatedText)
            )
        )
    }
}
