import NaturalLanguage

enum LanguageDetector {
    static func detect(_ text: String) -> String? {
        reading(text)?.code
    }

    // require higher confidence to change languages than to label detection
    static func reading(_ text: String) -> (code: String, confidence: Double)? {
        let sample = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard sample.count >= 3 else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        guard let language = recognizer.dominantLanguage else { return nil }

        let confidence = recognizer.languageHypotheses(withMaximum: 1)[language] ?? 0
        return (base(language.rawValue), confidence)
    }

    // normalize script-specific detection codes to the language catalogue
    private static func base(_ code: String) -> String {
        guard let dash = code.firstIndex(of: "-") else { return code }
        return String(code[..<dash])
    }
}

// avoid translating the detected language into itself
enum LanguagePairResolver {
    static let minimumConfidence = 0.80
    static let minimumLength = 12

    // only complete selections or paste-sized changes may realign languages
    static func shouldRealign(text: String,
                              previous: String,
                              arrivedWhole: Bool,
                              detected: (code: String, confidence: Double)?) -> Bool {
        guard let detected else { return false }
        guard detected.confidence >= minimumConfidence else { return false }
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumLength
        else { return false }
        if arrivedWhole { return true }
        // Net growth misses the commonest paste of all — select all, paste —
        // where 500 characters are swapped for 500 others. What matters is how
        // much of the text is new, so ignore the untouched head and tail.
        let head = text.commonPrefix(with: previous).count
        let tail = commonSuffixCount(text, previous, ignoringFirst: head)
        return text.count - head - tail >= minimumLength
    }

    /// Characters shared at the end of both strings, never reaching back into
    /// the `ignoringFirst` characters already counted as a common prefix.
    private static func commonSuffixCount(_ a: String, _ b: String,
                                          ignoringFirst head: Int) -> Int {
        var i = a.endIndex
        var j = b.endIndex
        var shared = 0
        let limit = min(a.count, b.count) - head
        while shared < limit, i > a.startIndex, j > b.startIndex {
            i = a.index(before: i)
            j = b.index(before: j)
            guard a[i] == b[j] else { break }
            shared += 1
        }
        return shared
    }

    static func realigned(detected: String,
                          source: String,
                          target: String,
                          preferred: [String]) -> (source: String, target: String)? {
        // The text is in the language we were about to translate *into*.
        if detected == target {
            // reverse an explicit pair
            if source != Languages.autoCode, source != detected {
                return (source: detected, target: source)
            }
            // keep auto-detection and choose another target
            guard let replacement = fallbackTarget(avoiding: detected, preferred: preferred) else {
                return nil
            }
            return (source: source, target: replacement)
        }

        // The target is fine but the source is wrong — the prompt would claim
        // the text is a language it plainly isn't, and models answer that by
        // echoing the input back untranslated.
        guard source != Languages.autoCode, source != detected else { return nil }
        return (source: detected, target: target)
    }

    static func fallbackTarget(avoiding detected: String, preferred: [String]) -> String? {
        if let pinned = preferred.first(where: { $0 != detected && $0 != Languages.autoCode }) {
            return pinned
        }
        return detected == "en" ? nil : "en"
    }
}
