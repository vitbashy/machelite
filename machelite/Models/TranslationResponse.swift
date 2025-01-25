struct TranslationResponse: Codable {
    let translations: [Translation]
}

struct Translation: Codable {
    let detectedSourceLanguage: String
    let text: String
    
    enum CodingKeys: String, CodingKey {
        case detectedSourceLanguage = "detected_source_language"
        case text
    }
}
