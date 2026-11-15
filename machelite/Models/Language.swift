import Foundation

struct Language: Identifiable, Hashable {
    let code: String      // iso 639-1
    let english: String
    let native: String

    var id: String { code }

    var display: String { english == native ? english : "\(english) — \(native)" }
}

enum Languages {
    static let autoCode = "auto"

    static let all: [Language] = [
        Language(code: "en", english: "English",    native: "English"),
        Language(code: "uk", english: "Ukrainian",  native: "Українська"),
        Language(code: "ru", english: "Russian",    native: "Русский"),
        Language(code: "de", english: "German",     native: "Deutsch"),
        Language(code: "fr", english: "French",     native: "Français"),
        Language(code: "es", english: "Spanish",    native: "Español"),
        Language(code: "pt", english: "Portuguese", native: "Português"),
        Language(code: "it", english: "Italian",    native: "Italiano"),
        Language(code: "nl", english: "Dutch",      native: "Nederlands"),
        Language(code: "pl", english: "Polish",     native: "Polski"),
        Language(code: "cs", english: "Czech",      native: "Čeština"),
        Language(code: "sk", english: "Slovak",     native: "Slovenčina"),
        Language(code: "sv", english: "Swedish",    native: "Svenska"),
        Language(code: "da", english: "Danish",     native: "Dansk"),
        Language(code: "nb", english: "Norwegian",  native: "Norsk"),
        Language(code: "fi", english: "Finnish",    native: "Suomi"),
        Language(code: "et", english: "Estonian",   native: "Eesti"),
        Language(code: "lv", english: "Latvian",    native: "Latviešu"),
        Language(code: "lt", english: "Lithuanian", native: "Lietuvių"),
        Language(code: "ro", english: "Romanian",   native: "Română"),
        Language(code: "hu", english: "Hungarian",  native: "Magyar"),
        Language(code: "bg", english: "Bulgarian",  native: "Български"),
        Language(code: "el", english: "Greek",      native: "Ελληνικά"),
        Language(code: "tr", english: "Turkish",    native: "Türkçe"),
        Language(code: "ar", english: "Arabic",     native: "العربية"),
        Language(code: "he", english: "Hebrew",     native: "עברית"),
        Language(code: "fa", english: "Persian",    native: "فارسی"),
        Language(code: "hi", english: "Hindi",      native: "हिन्दी"),
        Language(code: "bn", english: "Bengali",    native: "বাংলা"),
        Language(code: "ur", english: "Urdu",       native: "اردو"),
        Language(code: "th", english: "Thai",       native: "ไทย"),
        Language(code: "vi", english: "Vietnamese", native: "Tiếng Việt"),
        Language(code: "id", english: "Indonesian", native: "Bahasa Indonesia"),
        Language(code: "ms", english: "Malay",      native: "Bahasa Melayu"),
        Language(code: "zh", english: "Chinese",    native: "中文"),
        Language(code: "ja", english: "Japanese",   native: "日本語"),
        Language(code: "ko", english: "Korean",     native: "한국어"),
        Language(code: "ka", english: "Georgian",   native: "ქართული"),
        Language(code: "hy", english: "Armenian",   native: "Հայերեն"),
        Language(code: "az", english: "Azerbaijani", native: "Azərbaycan"),
        Language(code: "kk", english: "Kazakh",     native: "Қазақша"),
        Language(code: "sr", english: "Serbian",    native: "Српски"),
        Language(code: "hr", english: "Croatian",   native: "Hrvatski"),
        Language(code: "sl", english: "Slovenian",  native: "Slovenščina"),
        Language(code: "ca", english: "Catalan",    native: "Català"),
        Language(code: "is", english: "Icelandic",  native: "Íslenska"),
    ]

    private static let byCode: [String: Language] =
        Dictionary(uniqueKeysWithValues: all.map { ($0.code, $0) })

    static func named(_ code: String) -> Language? { byCode[code] }

    static func label(_ code: String) -> String {
        if code == autoCode { return "Detect language" }
        return byCode[code]?.english ?? code.uppercased()
    }

    static func promptName(_ code: String) -> String {
        if code == autoCode { return "the language it is written in" }
        return byCode[code]?.english ?? code
    }
}

enum LanguageSearch {
    static func matches(_ query: String) -> [Language] {
        let needle = fold(query)
        guard !needle.isEmpty else { return Languages.all }
        return Languages.all.filter { language in
            fold(language.english).contains(needle)
                || fold(language.native).contains(needle)
                || fold(language.code).contains(needle)
        }
    }

    static func fold(_ text: String) -> String {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive],
                     locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
