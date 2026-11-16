import Foundation

struct AnthropicClient: LLMClient {
    let apiKey: String
    let model: String

    private static let version = "2023-06-01"
    // share the provider base url
    private static let base = Provider.anthropic.baseURL

    private func request(_ path: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: Self.base.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.version, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        return request
    }

    func messagesRequest(
        system: String, user: String, maxTokens: Int, stream: Bool, tuned: Bool
    ) throws -> URLRequest {
        var body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [["role": "user", "content": user]],
        ]
        if stream { body["stream"] = true }
        if tuned { body["output_config"] = ["effort": "low"] }

        var request = self.request("messages", method: "POST")
        request.httpBody = try LLMTransport.encode(body)
        return request
    }

    func streamText(system: String, user: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let bytes = try await LLMTransport.withTuningFallback { tuned in
                        try await LLMTransport.open(
                            try messagesRequest(system: system, user: user,
                                                maxTokens: maxTokens, stream: true, tuned: tuned))
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard let payload = LLMTransport.payload(ofSSELine: line),
                              let event = LLMTransport.object(payload)
                        else { continue }

                        switch event["type"] as? String {
                        case "content_block_delta":
                            if let delta = event["delta"] as? [String: Any],
                               delta["type"] as? String == "text_delta",
                               let text = delta["text"] as? String {
                                continuation.yield(text)
                            }
                        case "error":
                            let error = event["error"] as? [String: Any]
                            throw LLMError.http(0, error?["message"] as? String ?? "Stream error.")
                        case "message_stop":
                            continuation.finish()
                            return
                        default:
                            continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func completeText(system: String, user: String, maxTokens: Int) async throws -> String {
        let object = try await LLMTransport.withTuningFallback { tuned in
            try await LLMTransport.json(
                try messagesRequest(system: system, user: user,
                                    maxTokens: maxTokens, stream: false, tuned: tuned))
        }
        guard let content = object["content"] as? [[String: Any]] else { throw LLMError.badResponse }
        let text = content
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else { throw LLMError.badResponse }
        return text
    }

    func listModels() async throws -> [String] {
        var request = self.request("models")
        request.url = URL(string: "models?limit=1000", relativeTo: Self.base)
        let object = try await LLMTransport.json(request)
        guard let data = object["data"] as? [[String: Any]] else { throw LLMError.badResponse }
        return data.compactMap { $0["id"] as? String }
    }
}
