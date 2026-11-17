import AppKit
import CoreGraphics

// cache font measurements instead of recomputing them during streaming
struct Typography {
    let body: CGFloat
    let lineSpacing: CGFloat
    let wordSpacing: CGFloat

    var cardLabel: CGFloat { 15 }
    var alternative: CGFloat { max(14, body - 4) }

    static let lineHeightMultiple: CGFloat = 1.40
    static let wordPadding: CGFloat = 2

    private init(_ size: TextSize) {
        let points = size.bodyPoints
        let font = NSFont.systemFont(ofSize: points)
        body = points

        // line spacing adds to the font’s natural line height
        let natural = NSLayoutManager().defaultLineHeight(for: font)
        lineSpacing = max(0, points * Typography.lineHeightMultiple - natural)

        // subtract word padding from the width of a real space
        let space = (" " as NSString).size(withAttributes: [.font: font]).width
        wordSpacing = max(0, space - Typography.wordPadding * 2)
    }

    private static let cache: [TextSize: Typography] =
        Dictionary(uniqueKeysWithValues: TextSize.allCases.map { ($0, Typography($0)) })

    static func metrics(for size: TextSize) -> Typography {
        cache[size] ?? Typography(.standard)
    }
}
