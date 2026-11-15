import Foundation

enum AlternativesEligibility {
    static let shortSentenceLimit = 120
    static let longSentenceLimit = 280

    static let shortSentenceCount = 3
    static let longSentenceCount = 1

    static func requestedCount(for source: String) -> Int {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        if trimmed.contains("\n") { return 0 }
        guard sentenceCount(in: trimmed) == 1 else { return 0 }

        let length = trimmed.count
        if length <= shortSentenceLimit { return shortSentenceCount }
        if length <= longSentenceLimit { return longSentenceCount }
        return 0
    }

    static func sentenceCount(in text: String) -> Int {
        var count = 0
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex,
                                 options: [.bySentences, .localized]) { substring, _, _, _ in
            if let substring,
               !substring.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                count += 1
            }
        }
        return count
    }
}
