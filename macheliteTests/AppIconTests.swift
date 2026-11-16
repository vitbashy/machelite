import SwiftUI
import Testing
@testable import machelite

struct AppIconTests {
    @Test func automaticFollowsThemeAndExplicitChoicesStayFixed() {
        #expect(AppIconStyle.automatic.resolved(isDark: false) == .sageRelief)
        #expect(AppIconStyle.automatic.resolved(isDark: true) == .mineralTeal)
        for style in AppIconStyle.allCases where style != .automatic {
            #expect(style.resolved(isDark: true) == style)
            #expect(style.resolved(isDark: false) == style)
        }
    }

}

struct DockIconCostTests {

    @Test func theDockIconIsSizedForTheDockNotForArtwork() {
        #expect(Constants.dockIconSide <= 128)
        #expect(Constants.dockIconScale >= 2)
    }

    @MainActor @Test func artworkRendersAtTheConfiguredPixelSize() throws {
        let renderer = ImageRenderer(content: AppIconArtwork(style: .mineralTeal)
            .frame(width: Constants.dockIconSide, height: Constants.dockIconSide))
        renderer.scale = Constants.dockIconScale
        let image = try #require(renderer.cgImage)
        let expected = Int(Constants.dockIconSide * Constants.dockIconScale)
        #expect(image.width == expected)
        #expect(image.height == expected)
    }
}
