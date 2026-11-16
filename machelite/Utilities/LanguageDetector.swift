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

enum LanguagePairResolver {
    static let minimumConfidence = 0.80
    static let minimumLength = 12

    static func shouldRealign(text: String,
                              previous: String,
                              arrivedWhole: Bool,
                              detected: (code: String, confidence: Double)?) -> Bool {
        guard let detected else { return false }
        guard detected.confidence >= minimumConfidence else { return false }
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumLength
        else { return false }
        if arrivedWhole { return true }
        // detect replacement pastes even when the total length stays the same
        let head = text.commonPrefix(with: previous).count
        let tail = commonSuffixCount(text, previous, ignoringFirst: head)
        return text.count - head - tail >= minimumLength
    }

    // exclude the prefix already counted so the shared ranges never overlap
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

        // correct the source without changing the user's target
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
