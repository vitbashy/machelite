import Foundation

struct OpenAICompatibleClient: LLMClient {
    let apiKey: String
    let model: String
    let baseURL: URL

    private static let excluded = [
        "embedding", "whisper", "tts", "dall-e", "moderation",
        "audio", "image", "transcribe", "realtime", "sora", "guard",
    ]

    private func request(_ path: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    // omit tuning parameters that some chat models reject internal, not private: covered directly by RequestBodyTests
    func chatRequest(system: String, user: String, maxTokens: Int,
                             stream: Bool, tuned: Bool) throws -> URLRequest {
        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ]
        if stream { body["stream"] = true }
        // retry without token tuning when the model rejects it
        if tuned { body["max_completion_tokens"] = maxTokens }

        var request = self.request("chat/completions", method: "POST")
        request.httpBody = try LLMTransport.encode(body)
        return request
    }

    func streamText(system: String, user: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let bytes = try await LLMTransport.withTuningFallback { tuned in
                        try await LLMTransport.open(
                            try chatRequest(system: system, user: user, maxTokens: maxTokens,
                                            stream: true, tuned: tuned))
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard let payload = LLMTransport.payload(ofSSELine: line) else { continue }
                        if payload == "[DONE]" { break }
                        guard let event = LLMTransport.object(payload) else { continue }
                        // surface stream errors instead of silently skipping them
                        if let failure = event["error"] as? [String: Any] {
                            throw LLMError.http(0, failure["message"] as? String
                                                ?? "The provider reported an error.")
                        }
                        guard let choices = event["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let text = delta["content"] as? String
                        else { continue }
                        continuation.yield(text)
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
                try chatRequest(system: system, user: user, maxTokens: maxTokens,
                                stream: false, tuned: tuned))
        }
        guard let choices = object["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String,
              !text.isEmpty
        else { throw LLMError.badResponse }
        return text
    }

    func listModels() async throws -> [String] {
        let object = try await LLMTransport.json(request("models"))
        guard let data = object["data"] as? [[String: Any]] else { throw LLMError.badResponse }
        return data
            .compactMap { $0["id"] as? String }
            .filter { id in !Self.excluded.contains { id.lowercased().contains($0) } }
    }
}
