import SwiftUI

struct WaveMark: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let x = rect.midX - side / 2
        let y = rect.midY - side / 2
        func point(_ px: CGFloat, _ py: CGFloat) -> CGPoint {
            CGPoint(x: x + px * side / 100, y: y + py * side / 100)
        }
        var centerline = Path()
        centerline.move(to: point(18, 40))
        centerline.addCurve(to: point(46, 64),
                            control1: point(18, 77), control2: point(42, 82))
        centerline.move(to: point(54, 36))
        centerline.addCurve(to: point(82, 60),
                            control1: point(58, 18), control2: point(82, 23))
        return centerline.strokedPath(StrokeStyle(lineWidth: side * 0.12,
                                                  lineCap: .round, lineJoin: .round))
    }
}

struct WaveMarkView: View {
    var size: CGFloat = 17
    var body: some View {
        WaveMark()
            .fill(.primary)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
