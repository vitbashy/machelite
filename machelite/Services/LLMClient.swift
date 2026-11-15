import Foundation

enum LLMError: LocalizedError {
    case missingKey(Provider)
    case missingModel(Provider)
    case http(Int, String)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .missingKey(let provider):
            return "Add your \(provider.title) API key in Settings (⌘,)."
        case .missingModel(let provider):
            return "Pick a \(provider.title) model in Settings (⌘,)."
        case .http(let code, let message):
            return message.isEmpty ? "Request failed (HTTP \(code))." : message
        case .badResponse:
            return "The provider returned something unreadable."
        }
    }
}

protocol LLMClient {
    func streamText(system: String, user: String, maxTokens: Int) -> AsyncThrowingStream<String, Error>
    func completeText(system: String, user: String, maxTokens: Int) async throws -> String
    func listModels() async throws -> [String]
}

enum LLMTransport {
    // bound the lifetime of stalled requests and streams
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 300
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    static func open(_ request: URLRequest) async throws -> URLSession.AsyncBytes {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMError.badResponse }
        guard http.statusCode == 200 else {
            var body = ""
            for try await line in bytes.lines {
                body += line
                if body.count > 8000 { break }
            }
            throw LLMError.http(http.statusCode, message(fromErrorBody: body))
        }
        return bytes
    }

    static func json(_ request: URLRequest) async throws -> [String: Any] {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMError.badResponse }
        guard http.statusCode == 200 else {
            throw LLMError.http(http.statusCode,
                                message(fromErrorBody: String(decoding: data, as: UTF8.self)))
        }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LLMError.badResponse
        }
        return object
    }

    static func message(fromErrorBody body: String) -> String {
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any],
              let message = error["message"] as? String
        else { return body.prefix(300).trimmingCharacters(in: .whitespacesAndNewlines) }
        return message
    }

    static func payload(ofSSELine line: String) -> String? {
        guard line.hasPrefix("data:") else { return nil }
        let value = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        return value.isEmpty ? nil : value
    }

    static func object(_ payload: String) -> [String: Any]? {
        guard let data = payload.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    static func encode(_ body: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: body)
    }

    // retry without optional tuning when a model rejects it
    static func withTuningFallback<T>(
        _ attempt: (_ tuned: Bool) async throws -> T
    ) async throws -> T {
        do {
            return try await attempt(true)
        } catch LLMError.http(400, _) {
            return try await attempt(false)
        }
    }
}
