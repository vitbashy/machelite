import AppKit
import Carbon.HIToolbox
import Testing
@testable import machelite

struct TokenizerTests {

    @Test func tokensReassembleIntoTheOriginal() {
        let text = "Use as little RAM as possible."
        let tokens = TextTokenizer.tokens(in: text)
        #expect(tokens.count == 6)
        #expect(tokens.map(\.display).joined(separator: " ") == text)
    }

    @Test func punctuationStaysWithItsWord() {
        let tokens = TextTokenizer.tokens(in: "Hello, world!")
        #expect(tokens.map(\.display) == ["Hello,", "world!"])
    }

    @Test func newlinesMarkLineBreaks() {
        let tokens = TextTokenizer.tokens(in: "first line\nsecond line")
        #expect(tokens.map(\.breaksLine) == [false, true, false, false])
    }

    @Test func spanRunsFromClickedWordToSentenceEnd() {
        let text = "Use as little RAM as possible. And then stop."
        let tokens = TextTokenizer.tokens(in: text)
        let span = TextTokenizer.replacementSpan(from: tokens[1].wordStart, in: text)
        #expect(String(text[span]) == "as little RAM as possible.")
    }

    @Test func spanStopsAtTheEndOfTheLastSentence() {
        let text = "One two three"
        let tokens = TextTokenizer.tokens(in: text)
        let span = TextTokenizer.replacementSpan(from: tokens[2].wordStart, in: text)
        #expect(String(text[span]) == "three")
    }

    @Test func emptyTextYieldsNoTokens() {
        #expect(TextTokenizer.tokens(in: "   ").isEmpty)
    }
}

struct OutputExtractorTests {

    @Test func pullsTheTranslationOutOfTheMarkers() {
        #expect(OutputExtractor.visible("<translation>used</translation>", finished: true) == "used")
    }

    @Test func discardsCommentaryBeforeTheMarkers() {
        let raw = """
            Бандит
            Wait, that's wrong direction. The input is "bandit" in English, \
            which is already English, so the rule says repeat it unchanged.
            <translation>bandit</translation>
            """
        #expect(OutputExtractor.visible(raw, finished: true) == "bandit")
    }

    @Test func discardsCommentaryAfterTheClosingMarker() {
        let raw = "<translation>used</translation>\n(past participle, neuter singular)"
        #expect(OutputExtractor.visible(raw, finished: true) == "used")
    }

    @Test func showsNothingUntilTheMarkerArrives() {
        #expect(OutputExtractor.visible("Hmm, the input looks", finished: false).isEmpty)
    }

    @Test func streamsContentOnceTheMarkerIsOpen() {
        #expect(OutputExtractor.visible("<translation>Вико", finished: false) == "Вико")
    }

    @Test func hidesAHalfTypedClosingMarker() {
        #expect(OutputExtractor.visible("<translation>used</transl", finished: false) == "used")
        #expect(OutputExtractor.visible("<translation>used<", finished: false) == "used")
    }

    @Test func keepsAngleBracketsThatAreNotTheClosingMarker() {
        #expect(OutputExtractor.visible("<translation>a < b", finished: false) == "a < b")
    }

    @Test func fallsBackToTheWholeResponseWhenMarkersNeverArrive() {
        #expect(OutputExtractor.visible("used", finished: true) == "used")
    }

    @Test func stripsStrayMarkersInTheFallbackPath() {
        #expect(OutputExtractor.visible("used</translation>", finished: true) == "used")
    }

    @Test func preservesInternalLineBreaks() {
        let raw = "<translation>first line\nsecond line</translation>"
        #expect(OutputExtractor.visible(raw, finished: true) == "first line\nsecond line")
    }
}

struct JSONArrayFinderTests {

    @Test func findsEverySeparateArray() {
        #expect(JSONArrayFinder.arraySpans(in: "[1] junk [2]") == ["[1]", "[2]"])
    }

    @Test func bracketsInsideStringsDoNotCountAsStructure() {
        let text = "[\"a ] b\", \"c [ d\"]"
        #expect(JSONArrayFinder.arraySpans(in: text) == [text])
        #expect(JSONArrayFinder.lastStringArray(in: text) == ["a ] b", "c [ d"])
    }

    @Test func escapedQuotesDoNotEndTheString() {
        let text = #"["say \"hi\""]"#
        #expect(JSONArrayFinder.lastStringArray(in: text) == [#"say "hi""#])
    }

    @Test func nestedArraysResolveToTheOuterSpan() {
        #expect(JSONArrayFinder.arraySpans(in: "[[1],[2]]") == ["[[1],[2]]"])
    }

    @Test func arraysOfNonStringsAreRejected() {
        #expect(JSONArrayFinder.lastStringArray(in: "[1, 2, 3]") == nil)
        #expect(JSONArrayFinder.lastStringArray(in: "[\"a\", 2]") == nil)
    }

    @Test func unterminatedArraysAreIgnored() {
        #expect(JSONArrayFinder.arraySpans(in: "[\"a\", \"b\"").isEmpty)
    }

    @Test func noArrayMeansNil() {
        #expect(JSONArrayFinder.lastStringArray(in: "no arrays here") == nil)
    }
}

struct AlternativesEligibilityTests {

    @Test func shortSingleSentenceAsksForThree() {
        #expect(AlternativesEligibility.requestedCount(
            for: "Давай зробимо щось просте й корисне.") == 3)
        #expect(AlternativesEligibility.requestedCount(
            for: "Let's make something simple and useful.") == 3)
    }

    @Test func multipleSentencesGetNone() {
        #expect(AlternativesEligibility.requestedCount(for: "Привіт! Як справи?") == 0)
        #expect(AlternativesEligibility.requestedCount(
            for: "Let's start. We can finish tomorrow.") == 0)
    }

    @Test func aLongerSingleSentenceAsksForOne() {
        let sentence = String(repeating: "word ", count: 36) + "end."
        #expect(sentence.count > AlternativesEligibility.shortSentenceLimit)
        #expect(sentence.count <= AlternativesEligibility.longSentenceLimit)
        #expect(AlternativesEligibility.requestedCount(for: sentence) == 1)
    }

    @Test func veryLongTextGetsNone() {
        let sentence = String(repeating: "word ", count: 80) + "end."
        #expect(sentence.count > AlternativesEligibility.longSentenceLimit)
        #expect(AlternativesEligibility.requestedCount(for: sentence) == 0)
    }

    @Test func emptyOrBlankInputGetsNone() {
        #expect(AlternativesEligibility.requestedCount(for: "") == 0)
        #expect(AlternativesEligibility.requestedCount(for: "   \n  ") == 0)
    }

    @Test func multipleParagraphsGetNoneEvenWithoutTerminalPunctuation() {
        #expect(AlternativesEligibility.requestedCount(for: "milk\nbread\neggs") == 0)
    }

    @Test func abbreviationsDoNotSplitTheSentence() {
        let text = "Dr. Smith arrived at 9 a.m. sharp."
        #expect(AlternativesEligibility.sentenceCount(in: text) == 1)
        #expect(AlternativesEligibility.requestedCount(for: text) == 3)
    }

    @Test func decimalsAndURLsDoNotSplitTheSentence() {
        #expect(AlternativesEligibility.sentenceCount(in: "It costs 3.50 today.") == 1)
        #expect(AlternativesEligibility.sentenceCount(in: "See https://example.com/a.b for details.") == 1)
    }

    @Test func lengthIsCountedInGraphemeClusters() {
        let text = "Ґґ Єє Іі Її 👨‍👩‍👧‍👦 зв'язок."
        #expect(text.count < AlternativesEligibility.shortSentenceLimit)
        #expect(AlternativesEligibility.requestedCount(for: text) == 3)
    }

    @Test func boundariesAreInclusive() {
        let atShortLimit = String(repeating: "a", count: 119) + "."
        #expect(atShortLimit.count == AlternativesEligibility.shortSentenceLimit)
        #expect(AlternativesEligibility.requestedCount(for: atShortLimit) == 3)

        let justOver = String(repeating: "a", count: 120) + "."
        #expect(justOver.count == AlternativesEligibility.shortSentenceLimit + 1)
        #expect(AlternativesEligibility.requestedCount(for: justOver) == 1)
    }
}

struct LanguageSearchTests {

    @Test func findsUkrainianByEnglishNameNativeSpellingAndCode() {
        for query in ["ukr", "Укра", "uk", "UKRAINIAN"] {
            let codes = LanguageSearch.matches(query).map(\.code)
            #expect(codes.contains("uk"), "query \(query) should reach Ukrainian")
        }
    }

    @Test func ignoresDiacritics() {
        #expect(LanguageSearch.matches("Francais").map(\.code).contains("fr"))
        #expect(LanguageSearch.matches("Español").map(\.code).contains("es"))
    }

    @Test func anEmptyQueryReturnsTheWholeCatalogue() {
        #expect(LanguageSearch.matches("").count == Languages.all.count)
        #expect(LanguageSearch.matches("   ").count == Languages.all.count)
    }

    @Test func nonsenseReturnsNothingSoThePanelCanSaySo() {
        #expect(LanguageSearch.matches("zzzzqq").isEmpty)
    }

}

struct StreamingExtractorTests {

    private func stream(_ chunks: [String], finished: Bool = true) -> String {
        var extractor = StreamingExtractor()
        for chunk in chunks { extractor.append(chunk) }
        return extractor.visible(finished: finished)
    }

    @Test func matchesTheOneShotExtractor() {
        let whole = "<translation>Let's make something simple and useful.</translation>"
        #expect(stream([whole]) == OutputExtractor.visible(whole, finished: true))
    }

    @Test func survivesAMarkerSplitAcrossChunks() {
        #expect(stream(["<trans", "lation>", "used", "</translation>"]) == "used")
        #expect(stream(["<", "t", "r", "a", "n", "s", "l", "a", "t", "i", "o", "n", ">", "ok"],
                       finished: false) == "ok")
    }

    @Test func discardsCommentaryBeforeTheMarker() {
        let chunks = ["Hmm, the source is already English. ",
                      "<translation>", "bandit", "</translation>"]
        #expect(stream(chunks) == "bandit")
    }

    @Test func hidesAHalfTypedClosingMarker() {
        #expect(stream(["<translation>used", "</transl"], finished: false) == "used")
    }

    @Test func showsNothingBeforeTheMarkerArrives() {
        #expect(stream(["Let me think about this"], finished: false).isEmpty)
    }

    @Test func fallsBackToTheWholeResponseWhenMarkersNeverArrive() {
        #expect(stream(["used"]) == "used")
    }

    @Test func keepsTheRawResponseForDiagnostics() {
        var extractor = StreamingExtractor()
        for chunk in ["<translation>", "a", "b", "</translation>"] { extractor.append(chunk) }
        #expect(extractor.raw == "<translation>ab</translation>")
    }

    @Test func preservesOutputAcrossManySmallChunks() {
        var extractor = StreamingExtractor()
        extractor.append("<translation>")
        for _ in 0..<2000 { extractor.append("word ") }
        #expect(extractor.visible(finished: false).count == 2000 * 5 - 1)
    }
}

struct LanguagePairResolverTests {

    @Test func pastingTheTargetLanguageFlipsThePair() {
        let pair = LanguagePairResolver.realigned(
            detected: "uk", source: "en", target: "uk", preferred: ["en", "uk"])
        #expect(pair?.source == "uk")
        #expect(pair?.target == "en")
    }

    @Test func aSensiblePairIsLeftAlone() {
        #expect(LanguagePairResolver.realigned(
            detected: "uk", source: "uk", target: "en", preferred: ["en", "uk"]) == nil)
    }

    @Test func autoDetectKeepsItsSourceAndMovesTheTarget() {
        let pair = LanguagePairResolver.realigned(
            detected: "uk", source: Languages.autoCode, target: "uk",
            preferred: ["uk", "en", "de"])
        #expect(pair?.source == Languages.autoCode)
        #expect(pair?.target == "en")
    }

    @Test func aPairPointingAtItselfStillResolves() {
        let pair = LanguagePairResolver.realigned(
            detected: "uk", source: "uk", target: "uk", preferred: ["uk", "de"])
        #expect(pair?.target == "de")
    }

    @Test func theFallbackSkipsTheDetectedLanguageAndAuto() {
        #expect(LanguagePairResolver.fallbackTarget(
            avoiding: "uk", preferred: [Languages.autoCode, "uk", "de"]) == "de")
        #expect(LanguagePairResolver.fallbackTarget(avoiding: "uk", preferred: []) == "en")
        #expect(LanguagePairResolver.fallbackTarget(avoiding: "en", preferred: ["en"]) == nil)
    }

    @Test func shortOrUncertainTextNeverMovesThePair() {
        #expect(!LanguagePairResolver.shouldRealign(
            text: "добрий", previous: "", arrivedWhole: false, detected: ("uk", 0.99)))
        #expect(!LanguagePairResolver.shouldRealign(
            text: "a reasonably long sentence", previous: "",
            arrivedWhole: false, detected: ("uk", 0.30)))
        #expect(LanguagePairResolver.shouldRealign(
            text: "чому такий широкий текст", previous: "",
            arrivedWhole: false, detected: ("uk", 0.95)))
    }

    @Test func typingOneMoreCharacterNeverFlipsAnExplicitPair() {
        let typed = "чому такий широкий текст у вікн"
        #expect(!LanguagePairResolver.shouldRealign(
            text: typed + "і", previous: typed,
            arrivedWhole: false, detected: ("uk", 0.99)))
    }

    @Test func editingInTheMiddleNeverFlipsThePair() {
        // Only one character changed, but everything after it shifts — a naive
        // prefix check would read that as a fresh paste.
        let before = "чому такий широкий текст у вікні програми"
        let after = "чому такий ширoкий текст у вікні програми"
        #expect(!LanguagePairResolver.shouldRealign(
            text: after, previous: before, arrivedWhole: false, detected: ("uk", 0.99)))
    }

    @Test func selectAllAndPasteRealignsEvenWithoutGrowth() {
        // The case that shipped broken: 495 characters swapped for 493, so net
        // growth was negative and the pair stayed on the old language.
        let german = String(repeating: "Das Entwicklungsteam schreibt die Schicht neu. ", count: 8)
        let ukrainian = String(repeating: "Команда розробників переписує шар синхронізації. ", count: 8)
        #expect(LanguagePairResolver.shouldRealign(
            text: ukrainian, previous: german, arrivedWhole: false, detected: ("uk", 0.99)))
    }

    @Test func deletingTextNeverFlipsThePair() {
        let full = "чому такий широкий текст у вікні програми сьогодні"
        #expect(!LanguagePairResolver.shouldRealign(
            text: String(full.prefix(30)), previous: full,
            arrivedWhole: false, detected: ("uk", 0.99)))
    }

    @Test func aWrongSourceIsCorrectedWhileTheTargetStands() {
        // German text in an explicit English → Ukrainian pair: the target is
        // what the user wants, only the source is a lie.
        let pair = LanguagePairResolver.realigned(
            detected: "de", source: "en", target: "uk", preferred: ["en", "uk"])
        #expect(pair?.source == "de")
        #expect(pair?.target == "uk")
    }

    @Test func anAutoSourceIsLeftAlone() {
        #expect(LanguagePairResolver.realigned(
            detected: "de", source: Languages.autoCode, target: "uk",
            preferred: ["en", "uk"]) == nil)
    }

    @Test func aPairThatAlreadyMatchesIsNotTouched() {
        #expect(LanguagePairResolver.realigned(
            detected: "de", source: "de", target: "uk", preferred: []) == nil)
    }

    @Test func shortcutTextAlwaysMayRealign() {
        #expect(LanguagePairResolver.shouldRealign(
            text: "чому такий широкий текст", previous: "",
            arrivedWhole: true, detected: ("uk", 0.95)))
    }

    @Test func realUkrainianIsDetectedConfidently() throws {
        let reading = try #require(LanguageDetector.reading(
            "Давай зробимо щось просте й корисне сьогодні."))
        #expect(reading.code == "uk")
        #expect(reading.confidence >= LanguagePairResolver.minimumConfidence)
    }
}

struct BlankResultRegressionTests {

    @Test func wordlessOutputProducesNoTokens() {
        #expect(TextTokenizer.tokens(in: "?!…").isEmpty)
        #expect(TextTokenizer.tokens(in: "— — —").isEmpty)
    }

    @Test func ordinaryOutputStillProducesTokens() {
        #expect(!TextTokenizer.tokens(in: "why is it so wide?").isEmpty)
    }
}
