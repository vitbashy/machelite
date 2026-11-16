import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blending: NSVisualEffectView.BlendingMode
    var emphasized: Bool = false

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blending
        view.isEmphasized = emphasized
        view.state = .active
    }
}

struct ShellBackground: View {
    let theme: Theme
    var neutral: Bool = false

    var body: some View {
        ZStack {
            if neutral {
                if !theme.reduceTransparency {
                    VisualEffectView(material: .underWindowBackground, blending: .behindWindow)
                }
                theme.panelSolid.opacity(theme.reduceTransparency ? 1 : 0.06)
            } else if theme.reduceTransparency {
                LinearGradient(colors: [theme.shellTop, theme.shellBottom],
                               startPoint: .top, endPoint: .bottom)
            } else {
                VisualEffectView(material: .underWindowBackground, blending: .behindWindow)
                LinearGradient(colors: [theme.shellTop, theme.shellBottom],
                               startPoint: .top, endPoint: .bottom)
            }
        }
        .ignoresSafeArea()
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            if !theme.reduceTransparency {
                GlassWindowRim()
            }
        }
    }
}

private struct GlassWindowRim: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(LinearGradient(stops: [
                    .init(color: .white.opacity(0.48), location: 0),
                    .init(color: .white.opacity(0.10), location: 0.45),
                    .init(color: .white.opacity(0.06), location: 0.65),
                    .init(color: .white.opacity(0.28), location: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.8)
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 2)
                .blur(radius: 3)
                .padding(2)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct GlassCapsule: ViewModifier {
    let theme: Theme
    // a flat surface keeps selectors consistent without extra glass shadows
    var flat = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if flat {
            content.background(theme.reduceTransparency ? theme.controlSolid : theme.rowTint, in: Capsule())
                .overlay(Capsule().strokeBorder(theme.rim.opacity(0.7), lineWidth: 0.7))
        } else if theme.reduceTransparency {
            content.background(theme.controlSolid, in: Capsule())
                .overlay(Capsule().strokeBorder(theme.hairline, lineWidth: 0.7))
        } else if #available(macOS 26.0, *) {
            // regular glass keeps controls distinct from the desktop behind them
            content.glassEffect(.regular.interactive(), in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 0.7))
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
                .background(theme.controlFill, in: Capsule())
                .overlay(Capsule().strokeBorder(theme.rim, lineWidth: 0.8))
                .shadow(color: theme.controlShadow, radius: 4, y: 2)
        }
    }
}

extension View {
    func glassCard(_ theme: Theme,
                   tint: Color,
                   solid: Color,
                   radius: CGFloat = 20,
                   elevation: CGFloat = 8,
                   material: NSVisualEffectView.Material = .contentBackground) -> some View {
        modifier(GlassCard(theme: theme, tint: tint, solid: solid,
                           radius: radius, elevation: elevation, material: material))
    }
}

private struct GlassCard: ViewModifier {
    let theme: Theme
    let tint: Color
    let solid: Color
    let radius: CGFloat
    let elevation: CGFloat
    let material: NSVisualEffectView.Material

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .background {
                ZStack {
                    if theme.reduceTransparency {
                        shape.fill(solid)
                    } else {
                        shape.fill(tint)
                    }
                }
            }
            .overlay { shape.strokeBorder(theme.rim, lineWidth: 0.8) }
            .shadow(color: theme.cardShadow, radius: elevation, y: elevation / 3)
    }
}
