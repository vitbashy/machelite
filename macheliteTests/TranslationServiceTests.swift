import AppKit
import Carbon.HIToolbox
import Testing
@testable import machelite

struct AlternativesParsingTests {

    @Test func parsesAPlainJSONArray() {
        let parsed = TranslationService.parseAlternatives(
            #"["the least RAM possible", "as little memory as it can"]"#)
        #expect(parsed == ["the least RAM possible", "as little memory as it can"])
    }

    @Test func parsesJSONWrappedInProseAndFences() {
        let raw = """
            Here are some options:
            ```json
            ["first", "second"]
            ```
            """
        #expect(TranslationService.parseAlternatives(raw) == ["first", "second"])
    }

    @Test func bulletedProseIsNoLongerAccepted() {
        let raw = """
            - the least RAM
            - minimal memory
            3. barely any RAM
            """
        #expect(TranslationService.parseAlternatives(raw).isEmpty)
    }

    @Test func stripsQuotesAndDropsDuplicates() {
        let parsed = TranslationService.parseAlternatives(
            #"["\"quoted\"", "same", "same", ""]"#)
        #expect(parsed == ["quoted", "same"])
    }
}

private final class RecordingClient: LLMClient {
    var systemPrompt = ""
    var userText = ""

    func streamText(system: String, user: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        systemPrompt = system
        userText = user
        return AsyncThrowingStream { $0.finish() }
    }

    func completeText(system: String, user: String, maxTokens: Int) async throws -> String {
        throw LLMError.badResponse
    }

    func listModels() async throws -> [String] { [] }
}

struct PromptTests {
    @Test func translateSubstitutesLanguagesAndAppendsStyleToCustomPrompt() async throws {
        let client = RecordingClient()
        let service = TranslationService(client: client,
            promptTemplate: "Keep formatting. Translate {source} into {target}.", style: .formal)
        for try await _ in service.translate("Привіт", from: "uk", to: "en") {}
        #expect(client.systemPrompt == "Keep formatting. Translate Ukrainian into English.\n\n"
                + TranslationStyle.formal.instruction(target: "English"))
        #expect(client.userText == "Привіт")
    }

    @Test func autoSourceReadsNaturallyInThePrompt() {
        #expect(Languages.promptName(Languages.autoCode) == "the language it is written in")
    }

    @Test func detectorRecognisesUkrainian() {
        #expect(LanguageDetector.detect("використовувати так мало ram скільки можливо") == "uk")
    }

    @Test func detectorIgnoresTinyInput() {
        #expect(LanguageDetector.detect("ok") == nil)
    }
}

struct PromptUpgradeTests {

    @Test func theDefaultAsksForTheMarkersTheExtractorLooksFor() {
        #expect(Constants.defaultTranslationPrompt.contains(OutputExtractor.openTag))
        #expect(Constants.defaultTranslationPrompt.contains(OutputExtractor.closeTag))
    }

}

struct AlternativesRobustnessTests {
    private let selfCorrectingReply = """
        ["Dozvil", "Право", "Згода", "Допуск"]
        Wait, that is not valid for the input. Let me redo it.
        ["дозвіл на вхід", "право доступу", "допуск", "санкція"]
        """

    @Test func takesTheArrayTheModelSettledOn() {
        #expect(TranslationService.parseAlternatives(selfCorrectingReply)
                == ["дозвіл на вхід", "право доступу", "допуск", "санкція"])
    }

    @Test func aReplyWithNoArrayYieldsNothingRatherThanProse() {
        #expect(TranslationService.parseAlternatives(
            "I'm sorry, I cannot do that.\nPlease rephrase.").isEmpty)
    }

    @Test func readsTheArrayInsideTheMarkers() {
        let raw = "<alternatives>[\"one\", \"two\"]</alternatives>"
        #expect(TranslationService.parseAlternatives(raw) == ["one", "two"])
    }

}

struct PromptCasingTests {

    @Test func theDefaultTellsTheModelToMirrorCapitalisation() {
        let prompt = Constants.defaultTranslationPrompt.lowercased()
        #expect(prompt.contains("capitalisation"))
        #expect(prompt.contains("lowercase"))
    }

    @Test func thePreviousDefaultUpgradesInsteadOfBeingKept() {
        #expect(Constants.supersededPrompts.count >= 1)
        #expect(!Constants.supersededPrompts.contains(Constants.defaultTranslationPrompt))
    }
}

struct AlternativeCasingTests {

    @MainActor @Test func bothAlternativePromptsCarryTheCasingRule() async {
        let client = AlternativesRecordingClient()
        let service = TranslationService(client: client,
                                         promptTemplate: Constants.defaultTranslationPrompt,
                                         style: .natural)
        _ = try? await service.sentenceAlternatives(
            source: "чому такий широкий?", sourceLanguage: "uk",
            translation: "why is it so wide?", targetLanguage: "en", count: 3)
        _ = try? await service.alternativesWithRaw(
            for: "wide?", source: "чому такий широкий?", sourceLanguage: "uk",
            translation: "why is it so wide?", targetLanguage: "en", count: 3)

        #expect(client.prompts.count == 2)
        for prompt in client.prompts {
            #expect(prompt.lowercased().contains("capitalisation"))
        }
    }
}

private final class AlternativesRecordingClient: LLMClient {
    var prompts: [String] = []

    func streamText(system: String, user: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }
    func completeText(system: String, user: String, maxTokens: Int) async throws -> String {
        prompts.append(user)
        return "<alternatives>[]</alternatives>"
    }
    func listModels() async throws -> [String] { [] }
}
