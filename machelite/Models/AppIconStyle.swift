import AppKit
import SwiftUI

enum AppIconStyle: String, CaseIterable, Identifiable {
    case automatic, sageRelief, mineralTeal, pearlPrism, plainStone, periwinkleInk, midnightInk, plainBlack
    var id: String { rawValue }
    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .sageRelief: "Sage relief"
        case .mineralTeal: "Mineral teal"
        case .pearlPrism: "Pearl prism"
        case .plainStone: "Plain stone"
        case .periwinkleInk: "Periwinkle ink"
        case .midnightInk: "Midnight ink"
        case .plainBlack: "Plain black"
        }
    }
    func resolved(isDark: Bool) -> Self {
        self == .automatic ? (isDark ? .mineralTeal : .sageRelief) : self
    }
}

// share the 20% enamel treatment between settings and dock rendering
struct AppIconArtwork: View {
    let style: AppIconStyle
    private let relief: CGFloat = 0.20

    private func rgb(_ hex: UInt32) -> Color {
        Color(red: Double((hex >> 16) & 255) / 255,
              green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255)
    }

    private var palette: [Color] {
        let values: [UInt32]
        switch style {
        case .automatic, .sageRelief: values = [0xedf4e8, 0xbed0b8, 0x98b392, 0x6f8b6b]
        case .mineralTeal: values = [0xb5ded2, 0x639e95, 0x356d69, 0x295b58]
        case .pearlPrism: values = [0xe4fff8, 0xbfdae0, 0xaea0d3, 0x7e84a9]
        case .plainStone: values = [0xe3e8e0, 0xb4bdb2, 0x88968a, 0x68796e]
        case .periwinkleInk: values = [0xd6ddfb, 0x96a8db, 0x647eb9, 0x45598d]
        case .midnightInk: values = [0x7f9bb8, 0x385a77, 0x1c3047, 0x101e30]
        case .plainBlack: values = [0x7b8981, 0x3f5148, 0x202f29, 0x12211b]
        }
        return values.map(rgb)
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let tile = size * 0.80
            let shape = RoundedRectangle(cornerRadius: tile * 0.225, style: .continuous)
            ZStack {
                ZStack {
                    shape.fill(palette[3])
                        .offset(y: size * (4 + 3 * relief) / 256)
                    shape.fill(LinearGradient(colors: Array(palette.prefix(3)),
                                              startPoint: UnitPoint(x: 0.12, y: 0),
                                              endPoint: UnitPoint(x: 0.8, y: 1)))
                    shape.fill(RadialGradient(colors: [.white.opacity(0.45), .clear],
                                              center: UnitPoint(x: 0.18, y: 0),
                                              startRadius: 0, endRadius: tile * 0.66))
                    // clip the reflection to the same contour as the enamel face
                    Ellipse()
                        .fill(LinearGradient(colors: [.white.opacity(0.32), .white.opacity(0.015)],
                                              startPoint: .top, endPoint: .bottom))
                        .frame(width: tile * 1.5, height: tile * 0.85)
                        .rotationEffect(.degrees(-16))
                        .offset(x: -tile * 0.12, y: -tile * 0.40)
                        .frame(width: tile, height: tile)
                        .clipShape(shape)
                    shape.strokeBorder(LinearGradient(stops: [
                        .init(color: .white.opacity(0.65), location: 0),
                        .init(color: .white.opacity(0.12), location: 0.45),
                        .init(color: palette[3].opacity(0.3), location: 0.75),
                        .init(color: .white.opacity(0.15), location: 1),
                    ], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: size * 2 / 256)
                }
                .frame(width: tile, height: tile)
                .shadow(color: rgb(0x142c29).opacity(0.28), radius: size * 10 / 256,
                        y: size * 12 / 256)

                wave(size: size)
                    .frame(width: tile * 132 / 204, height: tile * 132 / 204)
                    .offset(y: -size * relief * 2 * 1.32 / 256)
            }
            .frame(width: size, height: size)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func wave(size: CGFloat) -> some View {
        ZStack {
            ForEach(1...5, id: \.self) { layer in
                WaveMark().fill(rgb(0x64826c).opacity(relief))
                    .offset(y: size * CGFloat(layer) * 0.7 * 1.32 / 256)
            }
            WaveMark()
                .fill(LinearGradient(stops: [
                    .init(color: .white, location: 0),
                    .init(color: .white, location: 0.4),
                    .init(color: rgb(0xe5f2e6), location: 1),
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay {
                    WaveMark().stroke(LinearGradient(colors: [.white.opacity(0.9), .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: size * 0.4 / 256)
                }
        }
        .shadow(color: palette[3].opacity(0.65), radius: size * 3 * 1.32 / 256,
                y: size * 5 * 1.32 / 256)
    }
}

@MainActor
final class AppIconController {
    private var cache: [AppIconStyle: NSImage] = [:]
    func apply(light: AppIconStyle, dark darkStyle: AppIconStyle, appearance: AppearanceMode) {
        let dark: Bool
        switch appearance {
        case .light: dark = false
        case .dark: dark = true
        case .system:
            dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        }
        let resolved = (dark ? darkStyle : light).resolved(isDark: dark)
        if let image = cache[resolved] {
            NSApp.applicationIconImage = image
            return
        }
        let side = Constants.dockIconSide
        let renderer = ImageRenderer(content: AppIconArtwork(style: resolved)
            .frame(width: side, height: side))
        renderer.scale = Constants.dockIconScale
        guard let cgImage = renderer.cgImage else { return }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: side, height: side))
        cache[resolved] = image
        NSApp.applicationIconImage = image
    }
}
