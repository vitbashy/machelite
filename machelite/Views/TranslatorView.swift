import SwiftUI
import AppKit

struct TranslatorView: View {
    @EnvironmentObject private var model: TranslatorModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var inputFocused: Bool

    private var theme: Theme {
        Theme(colorScheme: colorScheme,
              reduceTransparency: settings.effectiveReduceTransparency,
              textSize: settings.textSize)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 16) {
                languageBar(availableWidth: geometry.size.width - 40)
                OriginalCard(focused: $inputFocused)
                    .frame(height: originalHeight(in: geometry.size))
                TranslationCard()
                    .frame(maxHeight: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, Constants.titlebarInset + 16)
            .padding(.bottom, 20)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .background(
            ZStack(alignment: .top) {
                ShellBackground(theme: theme)
                VStack(spacing: 0) {
                    theme.titleBand.frame(height: Constants.titlebarInset)
                    Rectangle().fill(theme.hairline).frame(height: 1)
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea()
            })
        .overlay(alignment: .topLeading) {
            AboutMark().padding(.leading, 100)
        }
        .environment(\.theme, theme)
        .foregroundStyle(theme.primaryText)
        .ignoresSafeArea()
        .onAppear { inputFocused = true }
    }

    private func originalHeight(in available: CGSize) -> CGFloat {
        let width = max(100, available.width - 84)
        let bounds = (model.inputText as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: theme.type.body)])
        let chromeHeight = CardLayout.headerHeight + CardLayout.contentSpacing + CardLayout.padding * 2
        let readingHeight = bounds.height * 1.4 + chromeHeight
        let minimumHeight = max(132, theme.type.body * 2 + 90)
        return min(max(minimumHeight, readingHeight),
                   max(minimumHeight, min(260, available.height * 0.34)))
    }

    private func languageBar(availableWidth: CGFloat) -> some View {
        let labels = [model.sourceLabel, Languages.label(settings.targetLanguage)]
        let font = NSFont.systemFont(ofSize: 15, weight: .medium)
        let labelWidth = labels.map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0
        let pickerWidth = min(max(180, ceil(labelWidth) + 64), max(180, (availableWidth - 58) / 2))

        return HStack(spacing: 12) {
            Spacer(minLength: 0)

            LanguagePicker(selection: $settings.sourceLanguage,
                           isSource: true,
                           label: model.sourceLabel,
                           detected: model.detectedCode,
                           width: pickerWidth,
                           onChange: { model.retranslate() })

            Button(action: { model.swapLanguages() }) {
                Image(systemName: "arrow.right.arrow.left")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.primaryText)
            .help("Swap languages (⇧⌘S)")
            .accessibilityLabel("Swap languages")

            LanguagePicker(selection: $settings.targetLanguage,
                           isSource: false,
                           label: Languages.label(settings.targetLanguage),
                           width: pickerWidth,
                           onChange: { model.retranslate() })

            Spacer(minLength: 0)
        }
        .environment(\.theme, theme)
    }
}

private enum CardLayout {
    static let headerHeight: CGFloat = 29
    static let contentSpacing: CGFloat = 12
    static let padding: CGFloat = 22
}

private struct OriginalCard: View {
    @EnvironmentObject private var model: TranslatorModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.theme) private var theme
    @FocusState.Binding var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: CardLayout.contentSpacing) {
            Text("Original")
                .font(.system(size: theme.type.cardLabel, weight: .semibold))
                .foregroundStyle(theme.cardLabelInk)
                .frame(height: CardLayout.headerHeight)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.inputText)
                    .font(.system(size: theme.type.body))
                    .lineSpacing(theme.type.lineSpacing)
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .focused($focused)
                    .padding(.leading, -5)
                    .accessibilityLabel("Text to translate")

                if model.inputText.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Type or paste text")
                            .font(.system(size: theme.type.body))
                        Text("or select any text and press \(settings.shortcut.display)")
                            .font(.system(size: max(11, theme.type.body * 0.6)))
                            .opacity(0.8)
                    }
                    .foregroundStyle(theme.tertiaryText)
                    .allowsHitTesting(false)
                }
            }
        }
        .padding(CardLayout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(theme, tint: theme.originalTint, solid: theme.originalSolid, radius: 22)
    }
}

private struct TranslationCard: View {
    @EnvironmentObject private var model: TranslatorModel
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.theme) private var theme
    @State private var justCopied = false

    var body: some View {
        VStack(alignment: .leading, spacing: CardLayout.contentSpacing) {
            header.frame(height: CardLayout.headerHeight)

            if let error = model.errorMessage {
                failure(error)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        result
                        if model.sentenceAlternativesLoading || !model.sentenceAlternatives.isEmpty {
                            alternativesSection
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.never)
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(CardLayout.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(theme, tint: theme.translationTint, solid: theme.translationSolid, radius: 22)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text("Translation")
                .font(.system(size: theme.type.cardLabel, weight: .semibold))
                .foregroundStyle(theme.cardLabelInk)

            StylePicker()

            if model.isTranslating {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .frame(width: 14, height: 14)
            }

            Spacer()

            Button(action: copy) {
                Image(systemName: justCopied ? "checkmark" : "square.on.square")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(justCopied ? theme.accent : theme.primaryText)
            .disabled(!model.canCopy)
            .opacity(model.canCopy ? 1 : 0)
            .help("Copy translation")
            .accessibilityLabel("Copy translation")
        }
    }

    private func copy() {
        model.copyOutput()
        withAnimation(.easeOut(duration: 0.15)) { justCopied = true }
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            withAnimation(.easeOut(duration: 0.2)) { justCopied = false }
        }
    }

    @ViewBuilder
    private var result: some View {
        if model.outputText.isEmpty {
            Text(model.isTranslating ? " " : "Translation")
                .font(.system(size: theme.type.body))
                .foregroundStyle(theme.tertiaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else if model.isTranslating || model.tokens.isEmpty {
            // fall back to plain text while streaming or when tokenization finds no words
            Text(model.outputText)
                .font(.system(size: theme.type.body))
                .lineSpacing(theme.type.lineSpacing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TranslationOutputView()
        }
    }

    private func failure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button("Retry") { model.retryTranslation() }
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var alternativesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(theme.hairline).frame(height: 1).padding(.vertical, 6)

            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: theme.type.cardLabel - 1))
                Text("Alternatives")
                    .font(.system(size: theme.type.cardLabel, weight: .semibold))
                if model.sentenceAlternativesLoading {
                    ProgressView().controlSize(.small).scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                }
            }
            .foregroundStyle(theme.primaryText)
            .padding(.bottom, 4)

            ForEach(Array(model.sentenceAlternatives.enumerated()), id: \.offset) { _, text in
                SentenceAlternativeRow(text: text) {
                    model.apply(sentenceAlternative: text)
                }
            }
        }
    }
}

private struct SentenceAlternativeRow: View {
    let text: String
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(text)
                    .font(.system(size: theme.type.alternative))
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(theme.tertiaryText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(hovering ? theme.rowHover : theme.rowTint))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.rim, lineWidth: 0.6))
            .shadow(color: theme.controlShadow, radius: 3, y: 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityHint("Replaces the translation with this wording")
    }
}

private struct AboutMark: View {
    @Environment(\.theme) private var theme
    @State private var showing = false

    var body: some View {
        Button { showing.toggle() } label: {
            WaveMarkView(size: 18)
                .frame(width: 18, height: Constants.titlebarInset)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("About Machelite")
        .onHover { $0 ? NSCursor.pointingHand.push() : NSCursor.pop() }
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            VStack(spacing: 2) {
                HStack(spacing: 0) {
                    Text("made with love by ")
                    // make the author link discoverable
                    Link(destination: Constants.authorURL) {
                        Text("vitbashy")
                            .fontWeight(.semibold)
                            .underline()
                            .foregroundStyle(theme.accent)
                    }
                    .buttonStyle(.plain)
                    .onHover { $0 ? NSCursor.pointingHand.push() : NSCursor.pop() }
                }
                Text("XOXO")
            }
            .font(.system(size: 12))
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
    }
}
