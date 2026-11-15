import SwiftUI

private struct LineBreakKey: LayoutValueKey {
    static let defaultValue = false
}

extension View {
    func breaksLine(_ value: Bool) -> some View {
        layoutValue(key: LineBreakKey.self, value: value)
    }
}

struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 5
    var lineSpacing: CGFloat = 7

    private struct Line {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func lines(maxWidth: CGFloat, subviews: Subviews) -> [Line] {
        var lines: [Line] = []
        var current = Line()

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil))
            let projected = current.indices.isEmpty
                ? size.width
                : current.width + horizontalSpacing + size.width

            if !current.indices.isEmpty && projected > maxWidth {
                lines.append(current)
                current = Line(indices: [index], width: size.width, height: size.height)
            } else {
                current.indices.append(index)
                current.width = projected
                current.height = max(current.height, size.height)
            }

            if subviews[index][LineBreakKey.self] {
                lines.append(current)
                current = Line()
            }
        }
        if !current.indices.isEmpty { lines.append(current) }
        return lines
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let laid = lines(maxWidth: maxWidth, subviews: subviews)
        let height = laid.reduce(0) { $0 + $1.height } +
            lineSpacing * CGFloat(max(0, laid.count - 1))
        let width = laid.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize,
                       subviews: Subviews, cache: inout ()) {
        let laid = lines(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for line in laid {
            var x = bounds.minX
            for index in line.indices {
                let size = subviews[index].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (line.height - size.height) / 2),
                    proposal: ProposedViewSize(size))
                x += size.width + horizontalSpacing
            }
            y += line.height + lineSpacing
        }
    }
}
