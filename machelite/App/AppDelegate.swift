import Cocoa
import SwiftUI
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {
    // Our key properties
    private var statusItem: NSStatusItem?
    private var popoverManager: PopoverManager?
    private var shortcutManager: ShortcutManager?
    private var translationService: TranslationService?
    
    // This creates our status bar item and window
    private func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request necessary permissions first
        requestPermissions()
        
        // Initialize our services
        translationService = TranslationService(apiKey: Constants.deeplAPIKey)
        shortcutManager = ShortcutManager()
        popoverManager = PopoverManager()
        
        // Setup our UI elements
        setupStatusBar()
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
        let pasteboard = NSPasteboard.general
        guard let selectedText = pasteboard.string(forType: .string) else { return }
        
        popoverManager?.updateOriginalText(selectedText)
        
        if let button = statusItem?.button {
            popoverManager?.show(relativeTo: button.bounds, of: button)
            
            translationService?.translate(selectedText) { [weak self] result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let translatedText):
                        self?.popoverManager?.updateTranslatedText(translatedText)
                    case .failure(let error):
                        print("Translation error: \(error)")
                    }
                }
            }
        }
    }
}

// Add this at the bottom of AppDelegate.swift
@main
struct macheliteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
