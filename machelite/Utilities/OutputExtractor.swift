import Foundation

enum OutputExtractor {
    static let openTag = "<translation>"
    static let closeTag = "</translation>"

    static func visible(_ raw: String, finished: Bool) -> String {
        guard let open = raw.range(of: openTag) else {
            return finished ? withoutMarkers(raw) : ""
        }

        var body = String(raw[open.upperBound...])
        if let close = body.range(of: closeTag) {
            body = String(body[..<close.lowerBound])
        } else if !finished {
            body = droppingPartialCloseTag(body)
        } else {
            body = withoutMarkers(body)
        }
        return body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func droppingPartialCloseTag(_ text: String) -> String {
        guard let last = text.lastIndex(of: "<") else { return text }
        let tail = text[last...]
        guard closeTag.hasPrefix(tail) else { return text }
        return String(text[..<last])
    }

    private static func withoutMarkers(_ text: String) -> String {
        text.replacingOccurrences(of: openTag, with: "")
            .replacingOccurrences(of: closeTag, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension OutputExtractor {
    static func between(_ open: String, _ close: String, in text: String) -> String? {
        guard let start = text.range(of: open) else { return nil }
        let rest = text[start.upperBound...]
        guard let end = rest.range(of: close) else { return String(rest) }
        return String(rest[..<end.lowerBound])
    }
}

enum JSONArrayFinder {
    static func arraySpans(in text: String) -> [String] {
        var spans: [String] = []
        var depth = 0
        var start: String.Index?
        var inString = false
        var escaped = false

        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]

            if inString {
                if escaped { escaped = false }
                else if character == "\\" { escaped = true }
                else if character == "\"" { inString = false }
            } else {
                switch character {
                case "\"":
                    inString = true
                case "[":
                    if depth == 0 { start = index }
                    depth += 1
                case "]":
                    if depth > 0 {
                        depth -= 1
                        if depth == 0, let opening = start {
                            spans.append(String(text[opening...index]))
                            start = nil
                        }
                    }
                default:
                    break
                }
            }
            index = text.index(after: index)
        }
        return spans
    }

    static func lastStringArray(in text: String) -> [String]? {
        for span in arraySpans(in: text).reversed() {
            guard let data = span.data(using: .utf8),
                  let items = try? JSONSerialization.jsonObject(with: data) as? [Any]
            else { continue }
            let strings = items.compactMap { $0 as? String }
            if !strings.isEmpty, strings.count == items.count { return strings }
        }
        return nil
    }
}

// retain marker state instead of rescanning the accumulated prefix
struct StreamingExtractor {
    private var prefix = ""
    private var body = ""
    private var foundOpen = false

    private(set) var raw = ""

    mutating func append(_ chunk: String) {
        raw += chunk
        guard !foundOpen else {
            body += chunk
            return
        }
        prefix += chunk
        guard let open = prefix.range(of: OutputExtractor.openTag) else {
            // keep only enough to recognise a marker split across chunks.
            if prefix.count > OutputExtractor.openTag.count * 2 {
                prefix = String(prefix.suffix(OutputExtractor.openTag.count))
            }
            return
        }
        foundOpen = true
        body = String(prefix[open.upperBound...])
        prefix = ""
    }

    func visible(finished: Bool) -> String {
        guard foundOpen else {
            // defer the unmarked fallback until the stream has finished
            return finished ? OutputExtractor.visible(raw, finished: true) : ""
        }
        var text = body
        if let close = text.range(of: OutputExtractor.closeTag) {
            text = String(text[..<close.lowerBound])
        } else if !finished {
            text = OutputExtractor.droppingPartialCloseTag(text)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
