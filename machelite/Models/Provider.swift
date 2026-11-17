import Foundation

enum Provider: String, CaseIterable, Identifiable {
    case anthropic
    case openai
    case openrouter

    var id: String { rawValue }

    var title: String {
        switch self {
        case .anthropic:  return "Anthropic"
        case .openai:     return "OpenAI"
        case .openrouter: return "OpenRouter"
        }
    }

    var usesAnthropicAPI: Bool { self == .anthropic }

    var baseURL: URL {
        switch self {
        case .anthropic:  return URL(string: "https://api.anthropic.com/v1/")!
        case .openai:     return URL(string: "https://api.openai.com/v1/")!
        case .openrouter: return URL(string: "https://openrouter.ai/api/v1/")!
        }
    }

    var keyHint: String {
        switch self {
        case .anthropic:  return "sk-ant-…"
        case .openai:     return "sk-…"
        case .openrouter: return "sk-or-v1-…"
        }
    }

    var consoleURL: URL {
        switch self {
        case .anthropic:  return URL(string: "https://console.anthropic.com/settings/keys")!
        case .openai:     return URL(string: "https://platform.openai.com/api-keys")!
        case .openrouter: return URL(string: "https://openrouter.ai/keys")!
        }
    }

}

enum LLMClientFactory {
    static func make(provider: Provider, key: String, model: String) -> LLMClient {
        if provider.usesAnthropicAPI {
            return AnthropicClient(apiKey: key, model: model)
        }
        return OpenAICompatibleClient(apiKey: key, model: model, baseURL: provider.baseURL)
    }
}
