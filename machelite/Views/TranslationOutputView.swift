import SwiftUI

struct TranslationOutputView: View {
    @EnvironmentObject private var model: TranslatorModel
    @Environment(\.theme) private var theme

    var body: some View {
        FlowLayout(horizontalSpacing: theme.type.wordSpacing,
                   lineSpacing: theme.type.lineSpacing) {
            ForEach(model.tokens) { token in
                WordView(token: token)
                    .breaksLine(token.breaksLine)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Translation")
        .accessibilityValue(model.outputText)
    }
}

private struct WordView: View {
    let token: WordToken

    @EnvironmentObject private var model: TranslatorModel
    @Environment(\.theme) private var theme
    @State private var hovering = false

    private var isActive: Bool { model.activeTokenID == token.id }

    var body: some View {
        Button {
            model.selectToken(token)
        } label: {
            Text(token.display)
                .font(.system(size: theme.type.body))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Typography.wordPadding)
                .padding(.vertical, 1)
                .background {
                    // Only the highlighted word owns a shape; a clear fill per
                    // word is still a view to lay out and composite.
                    if isActive {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(theme.accent.opacity(0.30))
                    } else if hovering {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(theme.primaryText.opacity(0.08))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isTranslating)
        .onHover { hovering = $0 }
        .accessibilityLabel(token.display)
        .accessibilityHint("Alternative continuations from this word")
        .popover(isPresented: Binding(
            get: { isActive },
            set: { if !$0 && isActive { model.dismissContinuations() } }
        ), arrowEdge: .bottom) {
            ContinuationPopover(
                word: model.activeWord,
                options: model.continuations,
                isLoading: model.continuationsLoading,
                error: model.continuationsError,
                onPick: { model.apply(continuation: $0) },
                onClose: { model.dismissContinuations() })
        }
    }
}
