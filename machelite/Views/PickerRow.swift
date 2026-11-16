import SwiftUI

struct PickerRow: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let isHighlighted: Bool
    var trailing: String?
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 14))
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 8)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.accent)
                } else if let trailing {
                    Image(systemName: trailing)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(theme.tertiaryText)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: subtitle == nil ? 36 : 44)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                let shape = RoundedRectangle(cornerRadius: Constants.pickerRowRadius, style: .continuous)
                if isSelected {
                    shape.fill(theme.selectionFill)
                } else if hovering {
                    shape.fill(theme.rowHover)
                }
            }
            .overlay {
                if isHighlighted && !isSelected {
                    RoundedRectangle(cornerRadius: Constants.pickerRowRadius, style: .continuous)
                        .strokeBorder(theme.focusRing, lineWidth: 1.5)
                }
            }
            .padding(.horizontal, Constants.pickerRowInset)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

struct PickerCapsule: View {
    let label: String
    let isOpen: Bool
    var compact: Bool = false
    let action: () -> Void

    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Group {
                if compact {
                    HStack(spacing: 8) {
                        title
                        chevron
                    }
                    .padding(.horizontal, 13)
                } else {
                    title
                        .padding(.horizontal, 12)
                        .frame(width: 130)
                        .frame(width: 150, alignment: .leading)
                        .overlay(alignment: .trailing) {
                            chevron.frame(width: 12).frame(width: 40)
                        }
                }
            }
            .frame(height: compact ? 29 : 40)
            .modifier(GlassCapsule(theme: theme))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var title: some View {
                Text(label)
                    .font(.system(size: compact ? 13 : 15, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
    }

    private var chevron: some View {
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: compact ? 9 : 11, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
    }
}

struct PickerPanelBackground: ViewModifier {
    let theme: Theme

    func body(content: Content) -> some View {
        content.background {
            if theme.reduceTransparency {
                theme.panelSolid
            } else {
                ZStack {
                    VisualEffectView(material: .popover, blending: .withinWindow)
                    theme.panelTint
                }
            }
        }
    }
}

extension View {
    func pickerPanel(_ theme: Theme) -> some View {
        modifier(PickerPanelBackground(theme: theme))
    }
}
