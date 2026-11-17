import AppKit
import Combine
import Foundation

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // honor either the app or system transparency preference
    var effectiveReduceTransparency: Bool {
        reduceTransparency || systemReduceTransparency
    }

    private let store = UserDefaults.standard
    private var accessibilityObserver: NSObjectProtocol?

    @Published var provider: Provider {
        didSet { store.set(provider.rawValue, forKey: Key.provider) }
    }
    @Published var anthropicModel: String {
        didSet { store.set(anthropicModel, forKey: Key.anthropicModel) }
    }
    @Published var openaiModel: String {
        didSet { store.set(openaiModel, forKey: Key.openaiModel) }
    }
    @Published var openrouterModel: String {
        didSet { store.set(openrouterModel, forKey: Key.openrouterModel) }
    }
    @Published var shortcut: ShortcutSpec {
        didSet {
            guard let data = try? JSONEncoder().encode(shortcut) else { return }
            store.set(data, forKey: Key.shortcut)
        }
    }
    @Published var translationPrompt: String {
        didSet { store.set(translationPrompt, forKey: Key.prompt) }
    }
    @Published var favoriteLanguages: [String] {
        didSet { store.set(favoriteLanguages, forKey: Key.favorites) }
    }
    @Published var sourceLanguage: String {
        didSet { store.set(sourceLanguage, forKey: Key.source) }
    }
    @Published var targetLanguage: String {
        didSet { store.set(targetLanguage, forKey: Key.target) }
    }
    @Published var alternativesCount: Int {
        didSet { store.set(alternativesCount, forKey: Key.altCount) }
    }
    @Published var translateOnType: Bool {
        didSet { store.set(translateOnType, forKey: Key.autoTranslate) }
    }
    @Published var appearance: AppearanceMode {
        didSet { store.set(appearance.rawValue, forKey: Key.appearance) }
    }
    // publish the system preference so SwiftUI observes changes
    @Published private(set) var systemReduceTransparency =
        NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency

    @Published var reduceTransparency: Bool {
        didSet { store.set(reduceTransparency, forKey: Key.reduceTransparency) }
    }
    @Published var style: TranslationStyle {
        didSet { store.set(style.rawValue, forKey: Key.style) }
    }
    @Published var lightAppIcon: AppIconStyle {
        didSet { store.set(lightAppIcon.rawValue, forKey: Key.lightAppIcon) }
    }
    @Published var darkAppIcon: AppIconStyle {
        didSet { store.set(darkAppIcon.rawValue, forKey: Key.darkAppIcon) }
    }
    func appIcon(isDark: Bool) -> AppIconStyle {
        (isDark ? darkAppIcon : lightAppIcon).resolved(isDark: isDark)
    }
    func setAppIcon(_ icon: AppIconStyle, isDark: Bool) {
        if isDark { darkAppIcon = icon } else { lightAppIcon = icon }
    }
    @Published var textSize: TextSize {
        didSet { store.set(textSize.rawValue, forKey: Key.textSize) }
    }

    private init() {
        let defaults: [String: Any] = [
            Key.provider: Provider.anthropic.rawValue,
            Key.prompt: Constants.defaultTranslationPrompt,
            Key.favorites: ["en", "uk", "ru", "de"],
            Key.source: Languages.autoCode,
            Key.target: "en",
            Key.altCount: 4,
            Key.autoTranslate: true,
            Key.appearance: AppearanceMode.system.rawValue,
            Key.reduceTransparency: false,
            Key.style: TranslationStyle.natural.rawValue,
            Key.textSize: TextSize.standard.rawValue,
            Key.lightAppIcon: AppIconStyle.sageRelief.rawValue,
            Key.darkAppIcon: AppIconStyle.mineralTeal.rawValue,
        ]
        store.register(defaults: defaults)

        provider = Provider(rawValue: store.string(forKey: Key.provider) ?? "") ?? .anthropic
        anthropicModel = store.string(forKey: Key.anthropicModel) ?? ""
        openaiModel = store.string(forKey: Key.openaiModel) ?? ""
        openrouterModel = store.string(forKey: Key.openrouterModel) ?? ""
        translationPrompt = store.string(forKey: Key.prompt) ?? Constants.defaultTranslationPrompt
        favoriteLanguages = store.stringArray(forKey: Key.favorites) ?? ["en", "uk", "ru", "de"]
        sourceLanguage = store.string(forKey: Key.source) ?? Languages.autoCode
        targetLanguage = store.string(forKey: Key.target) ?? "en"
        alternativesCount = store.integer(forKey: Key.altCount)
        translateOnType = store.bool(forKey: Key.autoTranslate)
        appearance = AppearanceMode(rawValue: store.string(forKey: Key.appearance) ?? "") ?? .system
        reduceTransparency = store.bool(forKey: Key.reduceTransparency)
        style = TranslationStyle(rawValue: store.string(forKey: Key.style) ?? "") ?? .natural
        lightAppIcon = AppIconStyle(rawValue: store.string(forKey: Key.lightAppIcon) ?? "") ?? .sageRelief
        darkAppIcon = AppIconStyle(rawValue: store.string(forKey: Key.darkAppIcon) ?? "") ?? .mineralTeal
        textSize = TextSize(rawValue: store.string(forKey: Key.textSize) ?? "") ?? .standard

        if let data = store.data(forKey: Key.shortcut),
           let stored = try? JSONDecoder().decode(ShortcutSpec.self, from: data) {
            shortcut = stored
        } else {
            shortcut = .default
        }

        if alternativesCount <= 0 { alternativesCount = 4 }

        // migrate known defaults while preserving custom prompts
        if Constants.supersededPrompts.contains(translationPrompt) {
            translationPrompt = Constants.defaultTranslationPrompt
        }

        accessibilityObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.systemReduceTransparency =
                    NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
            }
        }
    }

    var activeModel: String {
        get {
            switch provider {
            case .anthropic:  return anthropicModel
            case .openai:     return openaiModel
            case .openrouter: return openrouterModel
            }
        }
        set {
            switch provider {
            case .anthropic:  anthropicModel = newValue
            case .openai:     openaiModel = newValue
            case .openrouter: openrouterModel = newValue
            }
        }
    }

    // cache successful reads to avoid repeated keychain prompts
    private var secretCache: [Provider: String] = [:]

    // the last keychain failure, for Settings to surface.
    @Published private(set) var keychainError: String?

    // attribute-only lookup, so this never prompts.
    func hasKey(for provider: Provider) -> Bool {
        if let cached = secretCache[provider] { return !cached.isEmpty }
        return KeychainStore.exists(provider.rawValue)
    }

    // leave failed reads uncached so a later request can retry
    func secret(for provider: Provider) -> String {
        if let cached = secretCache[provider] { return cached }
        do {
            let value = try KeychainStore.read(provider.rawValue) ?? ""
            secretCache[provider] = value
            keychainError = nil
            return value
        } catch {
            keychainError = (error as? KeychainStore.Failure)?.message
                ?? error.localizedDescription
            return ""
        }
    }

    // keep the draft if the keychain write fails
    @discardableResult
    func setKey(_ value: String, for provider: Provider) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try KeychainStore.write(trimmed, account: provider.rawValue)
            objectWillChange.send()
            secretCache[provider] = trimmed
            keychainError = nil
            return true
        } catch {
            keychainError = (error as? KeychainStore.Failure)?.message
                ?? error.localizedDescription
            return false
        }
    }

    @discardableResult
    func removeKey(for provider: Provider) -> Bool {
        do {
            try KeychainStore.delete(provider.rawValue)
            objectWillChange.send()
            secretCache[provider] = ""
            keychainError = nil
            return true
        } catch {
            keychainError = (error as? KeychainStore.Failure)?.message
                ?? error.localizedDescription
            return false
        }
    }

    var hasKey: Bool { hasKey(for: provider) }

    func menuLanguages(including extras: [String]) -> [Language] {
        var seen = Set<String>()
        var result: [Language] = []
        for code in favoriteLanguages + extras {
            guard code != Languages.autoCode, !seen.contains(code) else { continue }
            seen.insert(code)
            if let language = Languages.named(code) { result.append(language) }
        }
        return result
    }

    func toggleFavorite(_ code: String) {
        if let index = favoriteLanguages.firstIndex(of: code) {
            guard favoriteLanguages.count > 1 else { return }
            favoriteLanguages.remove(at: index)
        } else {
            favoriteLanguages.append(code)
        }
    }

    func resetPrompt() { translationPrompt = Constants.defaultTranslationPrompt }

    private enum Key {
        static let provider = "provider"
        static let anthropicModel = "model.anthropic"
        static let openaiModel = "model.openai"
        static let openrouterModel = "model.openrouter"
        static let shortcut = "shortcut"
        static let prompt = "translationPrompt"
        static let favorites = "favoriteLanguages"
        static let source = "sourceLanguage"
        static let target = "targetLanguage"
        static let altCount = "alternativesCount"
        static let autoTranslate = "translateOnType"
        static let appearance = "appearance"
        static let reduceTransparency = "reduceTransparency"
        static let style = "translationStyle"
        static let lightAppIcon = "lightAppIcon"
        static let darkAppIcon = "darkAppIcon"
        static let textSize = "textSize"
    }
}
