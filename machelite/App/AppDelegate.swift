import Cocoa
import SwiftUI
import ApplicationServices

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var popoverManager: PopoverManager?
    private var shortcutManager: ShortcutManager?
    private var translationService: TranslationService?
    
    private func requestPermissions() {
        // Force prompt for accessibility permissions
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
        print("Accessibility enabled:", accessibilityEnabled)
        
        // Add hardened runtime entitlements
        if !AXIsProcessTrusted() {
            print("App not trusted - requesting permissions")
            let securityOptions = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
            AXIsProcessTrustedWithOptions(securityOptions as CFDictionary)
        }
    }
    
    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("Now I will request permissions")
        requestPermissions()
        
        translationService = TranslationService(apiKey: Constants.deeplAPIKey)
        shortcutManager = ShortcutManager()
        popoverManager = PopoverManager()
        
        setupStatusBar()
        setupShortcut()
        requestAccessibilityPermissions()
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

@main
struct macheliteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
