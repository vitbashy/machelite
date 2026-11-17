import CoreGraphics

enum TextSize: String, CaseIterable, Identifiable {
    case small, standard, large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small:    return "Small"
        case .standard: return "Default"
        case .large:    return "Large"
        }
    }

    var bodyPoints: CGFloat {
        switch self {
        case .small:    return 18
        case .standard: return 21
        case .large:    return 25
        }
    }
}
