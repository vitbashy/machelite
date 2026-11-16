import Foundation

enum TranslationStyle: String, CaseIterable, Identifiable {
    case natural, faithful, formal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .natural:  return "Natural"
        case .faithful: return "Faithful"
        case .formal:   return "Formal"
        }
    }

    var instruction: String {
        switch self {
        case .natural:
            return """
                Style: natural. Produce idiomatic \\(target) that a native speaker \
                would write, preserving the source meaning, register, formatting, \
                names and numbers. Add no information and no commentary.
                """
        case .faithful:
            return """
                Style: faithful. Stay as close as the target language allows to the \
                original wording, word order and sentence structure, while remaining \
                grammatical. Add no information and no commentary.
                """
        case .formal:
            return """
                Style: formal. Use a polite, professional written register, \
                preserving the source meaning, formatting, names and numbers. \
                Add no information and no commentary.
                """
        }
    }

    func instruction(target: String) -> String {
        instruction.replacingOccurrences(of: "\\(target)", with: target)
    }
}
