import AppKit
import Carbon.HIToolbox
import Testing
@testable import machelite

struct ShortcutSpecTests {

    @Test func defaultRendersTheWayDeepLShowsIt() {
        #expect(ShortcutSpec.default.display == "⌘CC")
    }

    @Test func singlePressIsNotDoubled() {
        let spec = ShortcutSpec(keyCode: UInt16(kVK_ANSI_C),
                                modifiers: NSEvent.ModifierFlags.command.rawValue,
                                isDoublePress: false)
        #expect(spec.display == "⌘C")
    }

    @Test func modifierGlyphsFollowAppleOrder() {
        let spec = ShortcutSpec(
            keyCode: UInt16(kVK_ANSI_T),
            modifiers: NSEvent.ModifierFlags([.command, .shift, .option, .control]).rawValue,
            isDoublePress: false)
        #expect(spec.display == "⌃⌥⇧⌘T")
    }

    @Test func multiCharacterKeysUseTimesTwoInsteadOfDoubling() {
        let spec = ShortcutSpec(keyCode: UInt16(kVK_Space),
                                modifiers: NSEvent.ModifierFlags.option.rawValue,
                                isDoublePress: true)
        #expect(spec.display == "⌥Space ×2")
    }

    @Test func onlyCommandCCountsAsSelfCopying() {
        #expect(ShortcutSpec.default.isCommandC)
        let optionSpace = ShortcutSpec(keyCode: UInt16(kVK_Space),
                                       modifiers: NSEvent.ModifierFlags.option.rawValue,
                                       isDoublePress: true)
        #expect(!optionSpace.isCommandC)
    }

    @Test func bareLettersAreRejectedButFunctionKeysAreNot() {
        #expect(!ShortcutSpec.isUsable(keyCode: UInt16(kVK_ANSI_C), flags: []))
        #expect(!ShortcutSpec.isUsable(keyCode: UInt16(kVK_ANSI_C), flags: [.shift]))
        #expect(ShortcutSpec.isUsable(keyCode: UInt16(kVK_ANSI_C), flags: [.command]))
        #expect(ShortcutSpec.isUsable(keyCode: UInt16(kVK_F5), flags: []))
    }

    @Test func matchingIgnoresCapsLock() throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero,
            modifierFlags: [.command, .capsLock], timestamp: 0,
            windowNumber: 0, context: nil,
            characters: "c", charactersIgnoringModifiers: "c",
            isARepeat: false, keyCode: UInt16(kVK_ANSI_C)))
        #expect(ShortcutSpec.default.matches(event))
    }

    @Test func matchingRejectsExtraModifiers() throws {
        let event = try #require(NSEvent.keyEvent(
            with: .keyDown, location: .zero,
            modifierFlags: [.command, .shift], timestamp: 0,
            windowNumber: 0, context: nil,
            characters: "C", charactersIgnoringModifiers: "C",
            isARepeat: false, keyCode: UInt16(kVK_ANSI_C)))
        #expect(!ShortcutSpec.default.matches(event))
    }

    @Test func survivesARoundTripThroughJSON() throws {
        let original = ShortcutSpec(keyCode: UInt16(kVK_F5),
                                    modifiers: NSEvent.ModifierFlags.option.rawValue,
                                    isDoublePress: true)
        let decoded = try JSONDecoder().decode(
            ShortcutSpec.self, from: try JSONEncoder().encode(original))
        #expect(decoded == original)
    }
}

struct ShortcutMechanismTests {

    @Test func everyShortcutNeedsKeystrokePermission() {
        let optionSpace = ShortcutSpec(keyCode: UInt16(kVK_Space),
                                       modifiers: NSEvent.ModifierFlags.option.rawValue,
                                       isDoublePress: true)
        let f5 = ShortcutSpec(keyCode: UInt16(kVK_F5), modifiers: 0, isDoublePress: false)

        for spec in [ShortcutSpec.default, optionSpace, f5] {
            #expect(spec.needsKeystrokePermission)
        }

        #expect(ShortcutSpec.default.isCommandC)
        #expect(!optionSpace.isCommandC)
        #expect(!f5.isCommandC)
    }

    @Test func carbonModifiersMapAcrossCorrectly() {
        let spec = ShortcutSpec(
            keyCode: UInt16(kVK_ANSI_T),
            modifiers: NSEvent.ModifierFlags([.command, .option]).rawValue,
            isDoublePress: false)
        #expect(spec.carbonModifiers == UInt32(cmdKey) | UInt32(optionKey))
    }

    @Test func noModifiersMeansNoCarbonMask() {
        let f5 = ShortcutSpec(keyCode: UInt16(kVK_F5), modifiers: 0, isDoublePress: false)
        #expect(f5.carbonModifiers == 0)
    }

}
