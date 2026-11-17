import Foundation

struct WordToken: Identifiable {
    let id: Int
    let display: String
    let wordStart: String.Index
    let breaksLine: Bool
}

enum TextTokenizer {
    static func tokens(in text: String) -> [WordToken] {
        var wordStarts: [String.Index] = []
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex,
                                 options: [.byWords, .substringNotRequired]) { _, range, _, _ in
            wordStarts.append(range.lowerBound)
        }
        guard !wordStarts.isEmpty else { return [] }

        var tokens: [WordToken] = []
        tokens.reserveCapacity(wordStarts.count)

        for index in wordStarts.indices {
            let start = index == 0 ? text.startIndex : wordStarts[index]
            let end = index + 1 < wordStarts.count ? wordStarts[index + 1] : text.endIndex
            let segment = String(text[start..<end])

            let trimmed = segment.replacingOccurrences(
                of: "\\s+$", with: "", options: .regularExpression)
            let trailing = segment.dropFirst(trimmed.count)

            tokens.append(WordToken(id: index,
                                    display: trimmed,
                                    wordStart: wordStarts[index],
                                    breaksLine: trailing.contains("\n")))
        }
        return tokens
    }

    static func replacementSpan(from start: String.Index, in text: String) -> Range<String.Index> {
        var end = text.endIndex
        text.enumerateSubstrings(in: text.startIndex..<text.endIndex,
                                 options: [.bySentences, .substringNotRequired]) { _, range, _, stop in
            if range.lowerBound <= start && start < range.upperBound {
                end = range.upperBound
                stop = true
            }
        }
        while end > start, let previous = text.index(end, offsetBy: -1, limitedBy: start),
              text[previous].isWhitespace {
            end = previous
        }
        return start..<max(start, end)
    }
}
