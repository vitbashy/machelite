import Foundation
import OSLog

struct DiagnosticEntry: Identifiable {
    let id = UUID()
    let date: Date
    let category: Category
    let summary: String
    let detail: String?

    enum Category: String {
        case request = "request"
        case response = "response"
        case failure = "error"
    }
}

@MainActor
final class DiagnosticsLog: ObservableObject {
    static let shared = DiagnosticsLog()

    private static let maxEntries = 80
    private static let maxDetailLength = 4000

    // derive the subsystem from the current bundle identifier
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "machelite", category: "translation")

    @Published private(set) var entries: [DiagnosticEntry] = []

    private init() {}

    func record(_ category: DiagnosticEntry.Category, _ summary: String, detail: String? = nil) {
        let trimmed = detail.map { text -> String in
            text.count > Self.maxDetailLength
                ? String(text.prefix(Self.maxDetailLength)) + "\n… (truncated)"
                : text
        }

        entries.insert(DiagnosticEntry(date: Date(), category: category,
                                       summary: summary, detail: trimmed),
                       at: 0)
        if entries.count > Self.maxEntries { entries.removeLast(entries.count - Self.maxEntries) }

        switch category {
        // keep provider errors and user content out of the persistent system log
        case .failure:  logger.error("translation failure: \(summary, privacy: .private)")
        case .request:  logger.info("translation request: \(summary, privacy: .private)")
        case .response: logger.debug("translation response: \(summary, privacy: .private)")
        }
    }

    func clear() { entries.removeAll() }

    var plainText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return entries.reversed().map { entry in
            var line = "[\(formatter.string(from: entry.date))] \(entry.category.rawValue): \(entry.summary)"
            if let detail = entry.detail { line += "\n\(detail)" }
            return line
        }.joined(separator: "\n\n")
    }
}
