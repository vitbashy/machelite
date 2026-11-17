import AppKit
import Combine
import SwiftUI

@main
enum Machelite {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        // retain the delegate for the application lifetime
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var diagnosticsWindow: NSWindow?
    private let shortcuts = ShortcutManager()
    private var cancellables = Set<AnyCancellable>()
    private var permissionTimer: Timer?
    private let appIconController = AppIconController()

    private func applyAppearance(_ mode: AppearanceMode? = nil) {
        NSApp.appearance = (mode ?? AppSettings.shared.appearance).nsAppearance
    }

    private func updateAppIcon() {
        let settings = AppSettings.shared
        appIconController.apply(light: settings.lightAppIcon, dark: settings.darkAppIcon,
                                appearance: settings.appearance)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        buildMenu()
        applyAppearance()
        showMainWindow()
        updateAppIcon()
        Publishers.CombineLatest3(AppSettings.shared.$lightAppIcon,
                                  AppSettings.shared.$darkAppIcon,
                                  AppSettings.shared.$appearance)
            .receive(on: RunLoop.main)
            .sink { [weak self] light, dark, appearance in
                self?.appIconController.apply(light: light, dark: dark, appearance: appearance)
            }
            .store(in: &cancellables)
        NSApp.publisher(for: \.effectiveAppearance)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateAppIcon() }
            .store(in: &cancellables)

        AppSettings.shared.$appearance
            .sink { [weak self] mode in self?.applyAppearance(mode) }
            .store(in: &cancellables)

        shortcuts.onUnavailable = { status in
            TranslatorModel.shared.shortcutUnavailable = true
            DiagnosticsLog.shared.record(
                .failure, "Could not claim the shortcut (status \(status)) — another app may own it")
        }
        shortcuts.onNothingCopied = {
            // report a failed copy instead of translating stale clipboard content
            NSSound.beep()
            DiagnosticsLog.shared.record(
                .failure, "Shortcut fired but nothing was copied — no selection?")
        }
        shortcuts.onTrigger = { [weak self] text in
            self?.handleShortcut(text)
        }
        AppSettings.shared.$shortcut
            .sink { [weak self] spec in
                TranslatorModel.shared.shortcutUnavailable = false
                self?.shortcuts.apply(spec)
            }
            .store(in: &cancellables)

        TranslatorModel.shared.$needsPermission
            .removeDuplicates()
            .sink { [weak self] needs in
                // rearm monitors when accessibility is granted during this launch
                guard !needs else { return }
                self?.shortcuts.reapply()
            }
            .store(in: &cancellables)

        promptForPermissionIfNeeded()
        startPermissionWatch()

    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        TranslatorModel.shared.refreshPermissionState()
    }

    private func startPermissionWatch() {
        TranslatorModel.shared.refreshPermissionState()
        // stop polling after two minutes; activation also refreshes permission
        var remaining = 60
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            Task { @MainActor in
                let model = TranslatorModel.shared
                model.refreshPermissionState()
                remaining -= 1
                if !model.needsPermission || remaining <= 0 {
                    timer.invalidate()
                    self?.permissionTimer = nil
                }
            }
        }
    }

    private func handleShortcut(_ text: String) {
        showMainWindow()
        NSApp.activate(ignoringOtherApps: true)
        TranslatorModel.shared.receive(text)
    }

    private func promptForPermissionIfNeeded() {
        guard AppSettings.shared.shortcut.needsKeystrokePermission else { return }
        guard !KeystrokePermission.isGranted else { return }
        // a new code signature can revoke a previous accessibility grant
        KeystrokePermission.request()
    }

    @objc func showMainWindow() {
        if let window = mainWindow {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let controller = NSHostingController(
            rootView: TranslatorView()
                .environmentObject(TranslatorModel.shared)
                .environmentObject(AppSettings.shared))
        // prevent hosting layout from shrinking the window
        controller.sizingOptions = []

        let window = MacheliteWindow(
            contentRect: NSRect(origin: .zero, size: Constants.windowDefaultSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        Self.makeTransparent(window)
        window.title = "Machelite"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.contentViewController = controller
        window.enforceMinimumContentSize(Constants.windowMinSize)
        // set after attaching the hosting controller
        window.setContentSize(Constants.windowDefaultSize)
        // restore the saved frame explicitly before falling back to centering
        let autosaveName = "macheliteMainWindow.v3"
        window.setFrameAutosaveName(autosaveName)
        if !window.setFrameUsingName(autosaveName) { window.center() }
        if window.frame.width < window.minSize.width || window.frame.height < window.minSize.height {
            window.setContentSize(Constants.windowDefaultSize)
        }
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)

        mainWindow = window
    }

    @objc func showSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(
            rootView: SettingsView()
                .environmentObject(AppSettings.shared)
                .environmentObject(TranslatorModel.shared))
        // prevent hosting layout from shrinking the window
        controller.sizingOptions = []

        let window = MacheliteWindow(
            contentRect: NSRect(origin: .zero, size: Constants.settingsSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        Self.makeTransparent(window)
        window.titleVisibility = .hidden
        window.title = "Settings"
        window.contentViewController = controller
        window.setContentSize(Constants.settingsSize)
        window.contentMinSize = Constants.settingsSize
        window.contentMaxSize = Constants.settingsSize
        window.minSize = window.frame.size
        window.maxSize = window.frame.size
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    private static func makeTransparent(_ window: NSWindow) {
        // desktop blur needs a transparent window
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
    }

    @objc func showDiagnostics() {
        if let window = diagnosticsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = NSHostingController(
            rootView: DiagnosticsView().environmentObject(DiagnosticsLog.shared))
        // prevent hosting layout from shrinking the window
        controller.sizingOptions = []

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 440),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.title = "Diagnostics"
        window.contentViewController = controller
        window.setContentSize(NSSize(width: 620, height: 440))
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        diagnosticsWindow = window
    }

    @objc private func translateNow() { TranslatorModel.shared.translateNow() }
    @objc private func swapLanguages() { TranslatorModel.shared.swapLanguages() }
    @objc private func clearText() { TranslatorModel.shared.clearInput() }

    // native editing shortcuts depend on the Edit menu
    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About Machelite",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
                        keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Machelite",
                        action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others",
                                    action: #selector(NSApplication.hideOtherApplications(_:)),
                                    keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Machelite",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All",
                         action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        let translateItem = NSMenuItem()
        let translateMenu = NSMenu(title: "Translate")
        let translate = NSMenuItem(title: "Translate Now",
                                   action: #selector(translateNow), keyEquivalent: "\r")
        translateMenu.addItem(translate)
        let swap = NSMenuItem(title: "Swap Languages",
                              action: #selector(swapLanguages), keyEquivalent: "s")
        swap.keyEquivalentModifierMask = [.command, .shift]
        translateMenu.addItem(swap)
        translateMenu.addItem(.separator())
        let clear = NSMenuItem(title: "Clear", action: #selector(clearText), keyEquivalent: "\u{8}")
        translateMenu.addItem(clear)
        translateItem.submenu = translateMenu
        mainMenu.addItem(translateItem)

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize",
                           action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(.separator())
        windowMenu.addItem(withTitle: "Machelite", action: #selector(showMainWindow), keyEquivalent: "0")
        let diagnostics = NSMenuItem(title: "Diagnostics",
                                     action: #selector(showDiagnostics), keyEquivalent: "l")
        diagnostics.keyEquivalentModifierMask = [.command, .option]
        windowMenu.addItem(diagnostics)
        windowItem.submenu = windowMenu
        mainMenu.addItem(windowItem)
        NSApp.windowsMenu = windowMenu

        NSApp.mainMenu = mainMenu
    }
}
