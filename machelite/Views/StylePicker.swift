import SwiftUI

struct StylePicker: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var model: TranslatorModel
    @Environment(\.theme) private var theme

    @State private var isPresented = false

    var body: some View {
        PickerCapsule(label: settings.style.title, isOpen: isPresented) {
            isPresented.toggle()
        }
        .accessibilityLabel("Translation style")
        .accessibilityValue(settings.style.title)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            StylePickerPanel(selection: settings.style) { style in
                isPresented = false
                guard settings.style != style else { return }
                settings.style = style
                model.retranslate()
            }
            .environment(\.theme, theme)
        }
    }
}

struct StylePickerPanel: View {
    let selection: TranslationStyle
    let onPick: (TranslationStyle) -> Void

    @Environment(\.theme) private var theme
    @State private var highlighted = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(TranslationStyle.allCases.enumerated()), id: \.element) { index, style in
                PickerRow(title: style.title,
                          isSelected: selection == style,
                          isHighlighted: highlighted == index) {
                    onPick(style)
                }
            }
        }
        .padding(.vertical, Constants.pickerRowInset)
        // keep the style picker sized to its labels
        .frame(minWidth: 150)
        .fixedSize(horizontal: true, vertical: false)
        .pickerPanel(theme)
        .onAppear {
            highlighted = TranslationStyle.allCases.firstIndex(of: selection) ?? 0
        }
        .onKeyPress(.upArrow) { move(-1); return .handled }
        .onKeyPress(.downArrow) { move(1); return .handled }
        .onKeyPress(.return) {
            onPick(TranslationStyle.allCases[highlighted])
            return .handled
        }
        .accessibilityLabel("Choose translation style")
    }

    private func move(_ delta: Int) {
        highlighted = max(0, min(TranslationStyle.allCases.count - 1, highlighted + delta))
    }
}
