import SwiftUI

struct ContinuationPopover: View {
    let word: String
    let options: [String]
    let isLoading: Bool
    let error: String?
    let onPick: (String) -> Void
    let onClose: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(word.isEmpty ? "Continue" : "Continue from “\(word)”")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.primaryText)
                .padding(.horizontal, 4)
                .padding(.bottom, 2)

            if isLoading {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Thinking…").font(.system(size: 14))
                }
                .foregroundStyle(theme.secondaryText)
                .padding(12)
            } else if let error {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundStyle(theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
            } else {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                            ContinuationRow(text: option) { onPick(option) }
                        }
                    }
                    .padding(2)
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: 280)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 8)
        .frame(width: 300, alignment: .leading)
        .background(theme.reduceTransparency ? theme.panelSolid : theme.panelTint)
        .onExitCommand(perform: onClose)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Continuations from \(word)")
    }
}

private struct ContinuationRow: View {
    let text: String
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(size: 15, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
            .foregroundStyle(theme.primaryText)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 32)
            .background(theme.reduceTransparency ? theme.controlSolid
                        : (hovering ? theme.rowHover : theme.rowTint),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(theme.rim, lineWidth: 0.7)
            }
            .shadow(color: theme.controlShadow, radius: 3, y: 2)
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(text)
    }
}
