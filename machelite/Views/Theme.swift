import SwiftUI

struct Theme {
    let colorScheme: ColorScheme
    let reduceTransparency: Bool
    var textSize: TextSize = .standard

    var type: Typography { Typography.metrics(for: textSize) }

    private var isDark: Bool { colorScheme == .dark }
    private var glass: Bool { !reduceTransparency }

    var shellTop: Color {
        if isDark {
            return Color(red: 0.14, green: 0.18, blue: 0.20).opacity(glass ? 0.08 : 1)
        }
        return Color(red: 0.81, green: 0.91, blue: 0.93).opacity(glass ? 0.08 : 1)
    }

    var shellBottom: Color {
        if isDark {
            return Color(red: 0.11, green: 0.15, blue: 0.17).opacity(glass ? 0.10 : 1)
        }
        return Color(red: 0.78, green: 0.90, blue: 0.88).opacity(glass ? 0.06 : 1)
    }

    var titleBand: Color {
        if isDark {
            return Color.white.opacity(glass ? 0.04 : 0.03)
        }
        return Color.white.opacity(glass ? 0.12 : 0.10)
    }

    var originalTint: Color {
        isDark ? Color(red: 0.20, green: 0.26, blue: 0.30).opacity(0.48)
               : Color.white.opacity(0.82)
    }
    var originalSolid: Color {
        isDark ? Color(red: 0.17, green: 0.20, blue: 0.22) : .white
    }

    var translationTint: Color {
        isDark ? Color(red: 0.17, green: 0.28, blue: 0.29).opacity(0.44)
               : Color(red: 0.91, green: 0.97, blue: 0.95).opacity(0.70)
    }
    var translationSolid: Color {
        isDark ? Color(red: 0.16, green: 0.19, blue: 0.21)
               : Color(red: 0.93, green: 0.97, blue: 0.95)
    }

    var panelTint: Color {
        isDark ? Color(red: 0.36, green: 0.43, blue: 0.47).opacity(0.28)
               : Color.white.opacity(0.50)
    }
    var panelSolid: Color {
        isDark ? Color(red: 0.17, green: 0.20, blue: 0.23)
               : Color(red: 0.98, green: 0.99, blue: 0.99)
    }

    var rowTint: Color {
        isDark ? Color.white.opacity(0.10)
               : Color.white.opacity(0.78)
    }
    var rowHover: Color {
        isDark ? Color.white.opacity(0.16)
               : Color.white.opacity(0.94)
    }

    var controlFill: Color {
        isDark ? Color(red: 0.31, green: 0.36, blue: 0.39).opacity(0.80)
               : Color.white.opacity(0.18)
    }
    var controlFillCompact: Color {
        isDark ? Color.white.opacity(0.16) : Color.white.opacity(0.80)
    }
    var controlSolid: Color {
        isDark ? Color(red: 0.27, green: 0.31, blue: 0.34) : .white
    }
    var controlShadow: Color {
        reduceTransparency ? .clear : .black.opacity(isDark ? 0.22 : 0.07)
    }

    var sidebarWash: Color {
        isDark ? Color.white.opacity(0.02) : Color.white.opacity(0.10)
    }

    var sidebarSelection: Color { Color.accentColor.opacity(isDark ? 0.40 : 0.25) }

    var selectionFill: Color {
        isDark ? Color(red: 0.36, green: 0.52, blue: 0.47).opacity(0.45)
               : Color(red: 0.80, green: 0.93, blue: 0.86).opacity(0.95)
    }
    var focusRing: Color { accent.opacity(isDark ? 0.75 : 0.55) }

    var primaryText: Color {
        isDark ? Color(red: 0.94, green: 0.96, blue: 0.96)
               : Color(red: 0.13, green: 0.16, blue: 0.18)
    }
    var secondaryText: Color { primaryText.opacity(0.60) }
    var cardLabelInk: Color { primaryText.opacity(0.85) }
    var tertiaryText: Color { primaryText.opacity(0.38) }

    var accent: Color {
        isDark ? Color(red: 0.56, green: 0.83, blue: 0.75)
               : Color(red: 0.20, green: 0.49, blue: 0.43)
    }

    var rim: Color {
        if reduceTransparency {
            return primaryText.opacity(isDark ? 0.25 : 0.18)
        }
        return isDark ? Color.white.opacity(0.20) : Color.white.opacity(0.65)
    }
    var hairline: Color { primaryText.opacity(isDark ? 0.12 : 0.09) }

    var cardShadow: Color {
        reduceTransparency ? .clear : .black.opacity(isDark ? 0.30 : 0.09)
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme(colorScheme: .light, reduceTransparency: false)
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}
