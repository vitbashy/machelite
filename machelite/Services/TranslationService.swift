import Foundation

struct TranslationService {
    let client: LLMClient
    let promptTemplate: String
    var style: TranslationStyle = .natural

    private func systemPrompt(source: String, target: String) -> String {
        let base = promptTemplate
            .replacingOccurrences(of: "{source}", with: Languages.promptName(source))
            .replacingOccurrences(of: "{target}", with: Languages.promptName(target))
        return base + "\n\n" + style.instruction(target: Languages.promptName(target))
    }

    func translate(_ text: String, from source: String, to target: String)
        -> AsyncThrowingStream<String, Error>
    {
        client.streamText(system: systemPrompt(source: source, target: target),
                          user: text,
                          maxTokens: 8192)
    }

    func sentenceAlternatives(
        source: String,
        sourceLanguage: String,
        translation: String,
        targetLanguage: String,
        count: Int
    ) async throws -> (alternatives: [String], raw: String) {
        let targetName = Languages.promptName(targetLanguage)
        let system = """
            You are a translator offering other ways to render one sentence.
            Reply with a JSON array of strings between <alternatives> and \
            </alternatives>, and write nothing outside those markers — no \
            commentary, no reasoning, no second thoughts.
            """

        let user = """
            Sentence (\(Languages.promptName(sourceLanguage))):
            \"\"\"
            \(source)
            \"\"\"

            A translation into \(targetName) already exists:
            \"\"\"
            \(translation)
            \"\"\"

            Give \(count) different complete translations of the same sentence \
            into \(targetName). Each one must:
            - render the whole sentence, not a fragment;
            - mirror the source's capitalisation: if the source is lowercase, \
            so is the alternative, and no sentence capital is added that the \
            source does not have;
            - stay faithful to the source meaning, register and formatting;
            - differ meaningfully from the existing translation and from each other;
            - never repeat the existing translation.

            \(style.instruction(target: targetName))

            Respond with exactly this shape and nothing else:
            <alternatives>[\"…\", \"…\"]</alternatives>
            """

        let raw = try await client.completeText(system: system, user: user, maxTokens: 2048)
        return (Self.parseAlternatives(raw), raw)
    }

    private func rawAlternatives(
        for fragment: String,
        source: String,
        sourceLanguage: String,
        translation: String,
        targetLanguage: String,
        count: Int
    ) async throws -> String {
        let system = """
            You are a bilingual editor refining an existing translation.
            Reply with a JSON array of strings between <alternatives> and \
            </alternatives>, and write nothing outside those markers — no \
            commentary, no reasoning, no second thoughts.
            """

        let user = """
            Source text (\(Languages.promptName(sourceLanguage))):
            \"\"\"
            \(source)
            \"\"\"

            Current translation (\(Languages.promptName(targetLanguage))):
            \"\"\"
            \(translation)
            \"\"\"

            The user clicked a word in the translation. This fragment runs from \
            that word to the end of its sentence:
            \"\"\"
            \(fragment)
            \"\"\"

            Give \(count) alternative ways to express that fragment in \
            \(Languages.promptName(targetLanguage)). Each one must:
            - mirror the capitalisation of the text it replaces, adding no \
            capital the original does not have;
            - be a drop-in replacement for the fragment, leaving the rest of the \
            sentence before it untouched and still reading correctly;
            - return only the replacement fragment, never repeat the sentence \
            prefix before the clicked word;
            - stay faithful to the source text;
            - differ meaningfully from the current wording and from each other;
            - keep the fragment's final punctuation.

            \(style.instruction(target: Languages.promptName(targetLanguage)))

            Respond with exactly this shape and nothing else:
            <alternatives>["…", "…"]</alternatives>
            """

        return try await client.completeText(system: system, user: user, maxTokens: 2048)
    }

    func alternativesWithRaw(
        for fragment: String,
        source: String,
        sourceLanguage: String,
        translation: String,
        targetLanguage: String,
        count: Int
    ) async throws -> ([String], String) {
        let raw = try await rawAlternatives(
            for: fragment, source: source, sourceLanguage: sourceLanguage,
            translation: translation, targetLanguage: targetLanguage, count: count)
        return (Self.parseAlternatives(raw), raw)
    }

    // require a json array so model commentary never becomes an option
    static func parseAlternatives(_ raw: String) -> [String] {
        let scoped = OutputExtractor.between("<alternatives>", "</alternatives>", in: raw) ?? raw
        guard let values = JSONArrayFinder.lastStringArray(in: scoped) else { return [] }
        return clean(values)
    }

    private static func clean(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values
            .map { value -> String in
                var text = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 1, text.hasPrefix("\""), text.hasSuffix("\"") {
                    text = String(text.dropFirst().dropLast())
                }
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
