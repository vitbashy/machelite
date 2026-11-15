import SwiftUI
import AppKit

@MainActor
final class ModelCatalog: ObservableObject {
    @Published var models: [String] = []
    @Published var isLoading = false
    @Published var error: String?

    private var loading: Task<Void, Never>?
    private var requested: Provider?

    func load(provider: Provider, key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            error = "Add an API key first."
            models = []
            return
        }

        isLoading = true
        error = nil
        loading?.cancel()
        requested = provider

        loading = Task {
            let client = LLMClientFactory.make(provider: provider, key: trimmed, model: "")
            do {
                let list = try await client.listModels().sorted()
                guard !Task.isCancelled, requested == provider else { return }
                models = list
                if models.isEmpty { error = "The provider returned no models." }
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, requested == provider else { return }
                self.error = error.localizedDescription
                models = []
            }
            isLoading = false
        }
    }

    // discard models from the previous provider
    func reset() {
        loading?.cancel()
        loading = nil
        requested = nil
        models = []
        error = nil
        isLoading = false
    }
}

enum SettingsSection: String, CaseIterable, Identifiable {
    case appearance, provider, languages, translation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .appearance:  return "Appearance"
        case .provider:    return "Provider"
        case .languages:   return "Languages"
        case .translation: return "Translation"
        }
    }

    var symbol: String {
        switch self {
        case .appearance:  return "display"
        case .provider:    return "square.stack.3d.up"
        case .languages:   return "textformat"
        case .translation: return "arrow.left.arrow.right"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme
    @State private var section: SettingsSection

    init(initialSection: SettingsSection = .appearance) {
        _section = State(initialValue: initialSection)
    }

    private var theme: Theme {
        Theme(colorScheme: colorScheme,
              reduceTransparency: settings.effectiveReduceTransparency,
              textSize: settings.textSize)
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            detail
        }
        .frame(width: Constants.settingsSize.width, height: Constants.settingsSize.height)
        .background(ShellBackground(theme: theme, neutral: true))
        .environment(\.theme, theme)
        .foregroundStyle(theme.primaryText)
        .ignoresSafeArea()
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 1) {
                Spacer().frame(height: Constants.titlebarInset + 4)
            ForEach(SettingsSection.allCases) { item in
                Button {
                    section = item
                } label: {
                    HStack(spacing: 9) {
                        Image(systemName: item.symbol)
                            .font(.system(size: 16, weight: .regular))
                            .frame(width: 22)
                        Text(item.title).font(.system(size: 15, weight: .regular))
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(section == item ? theme.sidebarSelection : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(section == item ? [.isSelected] : [])
            }
            Spacer()
        }
        .padding(10)
        .frame(width: Constants.settingsSidebarWidth, alignment: .top)
        .background {
            if theme.reduceTransparency {
                theme.panelSolid
            } else {
                theme.sidebarWash
            }
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(theme.hairline).frame(width: 1)
        }
        .overlay(alignment: .top) {
            Rectangle().fill(theme.hairline).frame(height: 1)
                .padding(.top, Constants.titlebarInset)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .topLeading) {
            WaveMarkView(size: 18)
                .frame(width: 18, height: Constants.titlebarInset)
                .padding(.leading, 100)
                .allowsHitTesting(false)
        }
    }

    private var detail: some View {
        VStack(spacing: 0) {
            HStack {
                Text(section.title)
                    .font(.system(size: 18, weight: .medium))
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: Constants.titlebarInset)
            .fixedSize(horizontal: false, vertical: true)
            .background(theme.titleBand)

            Rectangle().fill(theme.hairline).frame(height: 1)

            ScrollView {
                Group {
                    switch section {
                    case .appearance:  AppearanceSettings()
                    case .provider:    ProviderSettings()
                    case .languages:   LanguageSettings()
                    case .translation: TranslationSettings()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 12)
                .padding(.bottom, 18)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)
            .scrollIndicators(.hidden)
        }
        .frame(width: Constants.settingsSize.width - Constants.settingsSidebarWidth,
               height: Constants.settingsSize.height, alignment: .top)
    }
}

struct SettingsCard<Content: View>: View {
    @Environment(\.theme) private var theme
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(theme, tint: theme.panelTint, solid: theme.panelSolid, radius: 14, elevation: 2)
    }
}

struct SettingsRow<Control: View>: View {
    let title: String
    var detail: String?
    var showsDivider: Bool = false
    var verticalPadding: CGFloat = 11
    @ViewBuilder let control: () -> Control

    @Environment(\.theme) private var theme

    init(_ title: String, detail: String? = nil, showsDivider: Bool = false,
         verticalPadding: CGFloat = 11,
         @ViewBuilder control: @escaping () -> Control) {
        self.title = title
        self.detail = detail
        self.showsDivider = showsDivider
        self.verticalPadding = verticalPadding
        self.control = control
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .regular))
                    if let detail {
                        Text(detail)
                            .font(.system(size: 12))
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 12)
                control()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, verticalPadding)

            if showsDivider {
                Rectangle().fill(theme.hairline).frame(height: 1)
                    .padding(.leading, 16)
            }
        }
    }
}

private struct AppearanceSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.theme) private var theme

    private var systemForcesOpacity: Bool {
        settings.systemReduceTransparency
    }

    var body: some View {
        VStack(spacing: 12) {
            SettingsCard {
                SettingsRow("Theme", verticalPadding: 6) {
                    SettingsSegments(selection: $settings.appearance,
                                     values: AppearanceMode.allCases, title: { $0.title })
                        .frame(width: 260)
                }
            }
            SettingsCard {
                SettingsRow("Reduce transparency", detail: systemForcesOpacity
                            ? "Enabled by your Mac’s accessibility setting."
                            : "Use solid surfaces instead of glass.") {
                    Toggle("Reduce transparency", isOn: Binding(
                        get: { settings.effectiveReduceTransparency },
                        set: { settings.reduceTransparency = $0 }))
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                        .disabled(systemForcesOpacity)
                }
            }
            SettingsCard {
                SettingsRow("Text size") {
                    TextSizePicker()
                }
            }
            SettingsCard {
                SettingsRow("App icon", detail: "Choose an icon for the \(theme.colorScheme == .dark ? "dark" : "light") appearance.") {
                    HStack(spacing: 6) {
                        ForEach([AppIconStyle.sageRelief, .mineralTeal, .midnightInk, .pearlPrism,
                                 .periwinkleInk, .plainStone, .plainBlack]) { icon in
                            Button {
                                settings.setAppIcon(icon, isDark: theme.colorScheme == .dark)
                            } label: {
                                AppIconArtwork(style: icon)
                                    .frame(width: 44, height: 44)
                                    .background {
                                        RoundedRectangle(cornerRadius: 11)
                                            .strokeBorder(settings.appIcon(isDark: theme.colorScheme == .dark) == icon ? theme.accent : .clear,
                                                          lineWidth: 2)
                                    }
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .help(icon.title)
                            .accessibilityLabel(icon.title)
                            .accessibilityAddTraits(settings.appIcon(isDark: theme.colorScheme == .dark) == icon ? [.isSelected] : [])
                        }
                    }
                }
            }
        }
    }
}

private struct TextSizePicker: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        // use native controls consistently across settings
        Picker("", selection: $settings.textSize) {
            ForEach(TextSize.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .controlSize(.large)
        .fixedSize()
        .accessibilityLabel("Text size")
    }
}

private struct SettingsSegments<Value: Hashable>: View {
    @Binding var selection: Value
    let values: [Value]
    let title: (Value) -> String
    @Environment(\.theme) private var theme

    var body: some View {
        NativeSettingsSegments(titles: values.map(title), selectedIndex: Binding(
            get: { values.firstIndex(of: selection) ?? 0 },
            set: { if values.indices.contains($0) { selection = values[$0] } }),
            reduceTransparency: theme.reduceTransparency)
            .frame(height: 40)
    }
}

private struct NativeSettingsSegments: NSViewRepresentable {
    let titles: [String]
    @Binding var selectedIndex: Int
    let reduceTransparency: Bool

    func makeCoordinator() -> SegmentSelectionCoordinator { SegmentSelectionCoordinator() }

    func makeNSView(context: Context) -> SegmentHostView {
        let host = SegmentHostView()
        host.control.target = context.coordinator
        host.control.action = #selector(SegmentSelectionCoordinator.changed(_:))
        return host
    }

    func updateNSView(_ host: SegmentHostView, context: Context) {
        context.coordinator.onSelect = { selectedIndex = $0 }
        host.control.segmentCount = titles.count
        for (index, title) in titles.enumerated() { host.control.setLabel(title, forSegment: index) }
        host.control.selectedSegment = selectedIndex
        host.setGlassEnabled(!reduceTransparency)
    }
}

private final class SegmentSelectionCoordinator: NSObject {
    var onSelect: (Int) -> Void = { _ in }
    @objc func changed(_ sender: NSSegmentedControl) { onSelect(sender.selectedSegment) }
}

private final class SegmentHostView: NSView {
    let control = NSSegmentedControl()
    private var glass: NSView?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        control.trackingMode = .selectOne
        control.segmentStyle = .automatic
        if #available(macOS 26.0, *) {
            control.borderShape = .capsule
        }
        if #available(macOS 27.0, *) {
            control.role = .tabs
        }
        control.segmentDistribution = .fillEqually
        control.controlSize = .large
        control.font = .systemFont(ofSize: 14)
        control.setContentHuggingPriority(.defaultLow, for: .horizontal)
        addSubview(control)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setGlassEnabled(_ enabled: Bool) {
        if #available(macOS 27.0, *) {
            needsLayout = true
            return
        }
        if #available(macOS 26.0, *), enabled {
            if glass == nil {
                control.removeFromSuperview()
                let effect = NSGlassEffectView()
                effect.style = .clear
                effect.cornerRadius = 20
                if #available(macOS 27.0, *) { effect.effectIsInteractive = true }
                effect.contentView = control
                addSubview(effect)
                glass = effect
            }
        } else if let glass {
            if #available(macOS 26.0, *) { (glass as? NSGlassEffectView)?.contentView = nil }
            glass.removeFromSuperview()
            self.glass = nil
            addSubview(control)
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        glass?.frame = bounds
        control.frame = glass == nil ? bounds : bounds.insetBy(dx: 3, dy: 3)
    }
}

private struct ProviderSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.theme) private var theme
    @StateObject private var catalog = ModelCatalog()
    @State private var draftKey = ""
    @State private var revealDraft = false

    // cache key presence instead of querying from the view body
    @State private var storedKey = false

    private func refreshStoredKey() { storedKey = settings.hasKey(for: settings.provider) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SettingsCard {
                SettingsRow("Provider", verticalPadding: 6) {
                    SettingsSegments(selection: $settings.provider,
                                     values: Provider.allCases, title: { $0.title })
                    .frame(width: 310)
                    .onChange(of: settings.provider) { _, _ in
                        catalog.reset()
                        draftKey = ""
                        revealDraft = false
                        refreshStoredKey()
                    }
                }
            }

            SettingsCard {
                SettingsRow("API key", showsDivider: true) {
                    HStack(spacing: 6) {
                        Group {
                            if revealDraft {
                                TextField(keyPlaceholder, text: $draftKey)
                            } else {
                                SecureField(keyPlaceholder, text: $draftKey)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 250)
                        .onSubmit(saveDraft)

                        Button {
                            revealDraft.toggle()
                        } label: {
                            Image(systemName: revealDraft ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.secondaryText)
                        .disabled(draftKey.isEmpty)
                        .help("Show what you just typed")
                    }
                }

                HStack(spacing: 10) {
                    if let failure = settings.keychainError {
                        Label(failure, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    } else if storedKey {
                        Label("Stored in Keychain", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.green)
                    } else {
                        Text("No key stored yet.")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondaryText)
                    }
                    Spacer()
                    if !draftKey.isEmpty {
                        Button("Save", action: saveDraft).controlSize(.small)
                    }
                    if storedKey {
                        Button("Remove") {
                            // clear the draft only after the keychain operation succeeds
                            if settings.removeKey(for: settings.provider) { draftKey = "" }
                            refreshStoredKey()
                        }
                        .controlSize(.small)
                    }
                    Link("Get a key ↗", destination: settings.provider.consoleURL)
                        .font(.system(size: 11))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
            }

            SettingsCard {
                SettingsRow("Model", showsDivider: !catalog.models.isEmpty || catalog.error != nil) {
                    HStack(spacing: 8) {
                        if catalog.models.isEmpty {
                            TextField("Model ID", text: $settings.activeModel)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 210)
                        } else {
                            Picker("", selection: $settings.activeModel) {
                                // provide a valid empty selection on fresh installs
                                Text("Choose a model…").tag("")
                                // preserve model ids absent from the fetched list
                                if !settings.activeModel.isEmpty,
                                   !catalog.models.contains(settings.activeModel) {
                                    Text(settings.activeModel).tag(settings.activeModel)
                                }
                                ForEach(catalog.models, id: \.self) { Text($0).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 210)
                        }
                        Button {
                            catalog.load(provider: settings.provider,
                                         key: settings.secret(for: settings.provider))
                        } label: {
                            Label(catalog.isLoading ? "Loading…" : "Refresh models",
                                  systemImage: "arrow.clockwise")
                        }
                        .controlSize(.small)
                        .disabled(catalog.isLoading)
                    }
                }

                if !catalog.models.isEmpty || catalog.error != nil {
                VStack(alignment: .leading, spacing: 6) {
                    if !catalog.models.isEmpty {
                        TextField("Or type a model ID", text: $settings.activeModel)
                            .textFieldStyle(.roundedBorder)
                    }
                    if let error = catalog.error {
                        Text(error).font(.system(size: 11)).foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                }
            }
        }
        .onAppear(perform: refreshStoredKey)
    }

    private var keyPlaceholder: String {
        storedKey ? "Enter a new key to replace it" : settings.provider.keyHint
    }

    private func saveDraft() {
        guard !draftKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        // keep the draft if the keychain write fails
        guard settings.setKey(draftKey, for: settings.provider) else { return }
        draftKey = ""
        revealDraft = false
        refreshStoredKey()
    }
}

private struct LanguageSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.theme) private var theme
    @State private var query = ""

    private var matches: [Language] { LanguageSearch.matches(query) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pinned languages").font(.system(size: 17, weight: .semibold))

            SettingsCard {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(theme.secondaryText)
                    TextField("Search languages", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(theme.primaryText.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(theme.hairline, lineWidth: 0.7))
                .padding(10)

                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(matches) { language in
                            Toggle(isOn: Binding(
                                get: { settings.favoriteLanguages.contains(language.code) },
                                set: { _ in settings.toggleFavorite(language.code) }
                            )) {
                                Text(language.native).font(.system(size: 15, weight: .regular))
                            }
                            .toggleStyle(ReferenceCheckbox())
                            .padding(.horizontal, 16)
                            .frame(height: 32)
                            .frame(maxWidth: .infinity, alignment: .leading)

                            if language.code != matches.last?.code {
                                Rectangle().fill(theme.hairline).frame(height: 1)
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }
                .frame(height: 197)
            }

            Text("Pinned languages appear first.")
                .font(.system(size: 11))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ReferenceCheckbox: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button { configuration.isOn.toggle() } label: {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(configuration.isOn ? Color.accentColor : .clear)
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(configuration.isOn ? Color.accentColor : Color.secondary.opacity(0.4), lineWidth: 1)
                    if configuration.isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 15, height: 15)
                configuration.label
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "Pinned" : "Not pinned")
        .accessibilityAddTraits(configuration.isOn ? [.isSelected] : [])
    }
}

private struct AlternativesCountField: View {
    @Binding var value: Int
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            Text("\(value)").font(.system(size: 13, weight: .medium))
                .monospacedDigit().frame(minWidth: 22)
            VStack(spacing: 0) {
                arrow("chevron.up", change: 1)
                arrow("chevron.down", change: -1)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 29)
        .background(theme.rowTint, in: Capsule())
        .overlay(Capsule().strokeBorder(theme.hairline, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Alternatives per word")
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(8, value + 1)
            case .decrement: value = max(2, value - 1)
            @unknown default: break
            }
        }
    }

    private func arrow(_ name: String, change: Int) -> some View {
        Button { value = min(8, max(2, value + change)) } label: {
            Image(systemName: name).font(.system(size: 8, weight: .semibold))
                .frame(width: 18, height: 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(change > 0 ? value >= 8 : value <= 2)
        .accessibilityLabel(change > 0 ? "More alternatives" : "Fewer alternatives")
    }
}

private struct TranslationSettings: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var model: TranslatorModel
    @Environment(\.theme) private var theme
    @State private var showAdvanced = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsCard {
                SettingsRow("Translate selected text", showsDivider: true) {
                    ShortcutField(spec: $settings.shortcut)
                }

                SettingsRow("Translate while typing", showsDivider: true) {
                    Toggle("Translate while typing", isOn: $settings.translateOnType)
                        .labelsHidden().toggleStyle(.switch).controlSize(.small)
                }

                SettingsRow("Alternatives per word") {
                    AlternativesCountField(value: $settings.alternativesCount)
                }
            }

            SettingsCard {
                // place the disclosure chevron after the label
                VStack(alignment: .leading, spacing: 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) { showAdvanced.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Advanced").font(.system(size: 14, weight: .regular))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(theme.secondaryText)
                                .rotationEffect(.degrees(showAdvanced ? 90 : 0))
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Advanced")
                    .accessibilityValue(showAdvanced ? "Expanded" : "Collapsed")
                    .accessibilityHint("Shows the translation prompt")

                    if showAdvanced {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Translation prompt").font(.system(size: 13, weight: .regular))
                            TextEditor(text: $settings.translationPrompt)
                                .font(.system(size: 11, design: .monospaced))
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .frame(height: 86)
                                .background(RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.rowTint))
                            HStack(alignment: .top) {
                                Text("Copy twice to translate selected text.")
                                    .font(.system(size: 11))
                                    .foregroundStyle(theme.secondaryText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Button("Restore default") { settings.resetPrompt() }
                                    .controlSize(.small)
                            }
                        }
                        .padding(.top, 10)
                        .transition(.opacity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            if settings.shortcut.needsKeystrokePermission { PermissionNotice() }
            if model.shortcutUnavailable { ShortcutConflictNotice() }
        }
    }
}

private struct PermissionNotice: View {
    @EnvironmentObject private var model: TranslatorModel
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            if model.needsPermission {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle").foregroundStyle(theme.secondaryText)
                    Text("Enable \(AppSettings.shared.shortcut.display) in macOS.")
                        .font(.system(size: 11))
                    Spacer(minLength: 8)
                    Button("Open System Settings") { KeystrokePermission.openSettings() }
                        .controlSize(.small)
                }
                .padding(.horizontal, 4)
                .foregroundStyle(theme.secondaryText)
            }
        }
        .onAppear { model.refreshPermissionState() }
    }
}

private struct ShortcutConflictNotice: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
            Text("Another app is using this shortcut. Pick a different one.")
                .font(.system(size: 11))
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 4)
        .foregroundStyle(theme.secondaryText)
    }
}
