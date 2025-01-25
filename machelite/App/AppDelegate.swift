import Cocoa
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    // Our main window and status bar item
    private var window: NSWindow?
    private var statusItem: NSStatusItem?
    
    // Managers for different functionalities
    private var popoverManager: PopoverManager?
    private var shortcutManager: ShortcutManager?
    private var translationService: TranslationService?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize our services
        translationService = TranslationService(apiKey: Constants.deeplAPIKey)
        shortcutManager = ShortcutManager()
        popoverManager = PopoverManager()
        
        // Setup status bar item
        setupStatusBar()
        
        // Setup global shortcut
        setupShortcut()
    }
    
    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "globe", accessibilityDescription: "Translate")
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Translate Selection", action: #selector(translateSelection), keyEquivalent: "t"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupShortcut() {
        shortcutManager?.shortcutHandler = { [weak self] in
            self?.handleShortcutPressed()
        }
        shortcutManager?.registerGlobalShortcut()
    }
    
    @objc private func translateSelection() {
        handleShortcutPressed()
    }
    
    private func handleShortcutPressed() {
        // Get selected text using pasteboard (clipboard)
        let pasteboard = NSPasteboard.general
        guard let selectedText = pasteboard.string(forType: .string) else { return }
        
        // Update the original text in our view
        popoverManager?.updateOriginalText(selectedText)
        
        // Show the popover
        if let button = statusItem?.button {
            popoverManager?.show(relativeTo: button.bounds, of: button)
            
            // Translate the text
            translationService?.translate(selectedText) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let translatedText):
                        self?.popoverManager?.updateTranslatedText(translatedText)
                    case .failure(let error):
                        // Handle error - we'll add error handling later
                        print("Translation error: \(error)")
                    }
                }
            }
        }
    }
}

private func requestPermissions() {
    // Request accessibility permissions
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    AXIsProcessTrustedWithOptions(options as CFDictionary)
}
