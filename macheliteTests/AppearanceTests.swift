import AppKit
import Carbon.HIToolbox
import Testing
@testable import machelite

struct AppearanceModeTests {

    @Test func systemClearsTheOverrideSoTheMacDecides() {
        #expect(AppearanceMode.system.nsAppearance == nil)
    }

    @Test func lightAndDarkMapToRealAppearances() {
        #expect(AppearanceMode.light.nsAppearance?.name == .aqua)
        #expect(AppearanceMode.dark.nsAppearance?.name == .darkAqua)
    }

}

struct TypographyTests {

    @Test func lineHeightLandsInTheRequestedBandAtEverySize() {
        for size in TextSize.allCases {
            let type = Typography.metrics(for: size)
            let font = NSFont.systemFont(ofSize: type.body)
            let natural = NSLayoutManager().defaultLineHeight(for: font)
            let ratio = (natural + type.lineSpacing) / type.body
            #expect(ratio >= 1.35 && ratio <= 1.45, "ratio \(ratio) at \(size.rawValue)")
        }
    }

    @Test func wordGapsMatchARealSpaceAtEverySize() {
        for size in TextSize.allCases {
            let type = Typography.metrics(for: size)
            let font = NSFont.systemFont(ofSize: type.body)
            let space = (" " as NSString).size(withAttributes: [.font: font]).width
            #expect(abs(type.wordSpacing + Typography.wordPadding * 2 - space) < 0.01)
        }
    }

}
