import Foundation
import AppKit
import Carbon.HIToolbox
import Testing
@testable import machelite

struct ProviderTests {

    @Test func openRouterSpeaksTheOpenAIProtocol() {
        #expect(!Provider.openrouter.usesAnthropicAPI)
        #expect(Provider.openrouter.baseURL.absoluteString == "https://openrouter.ai/api/v1/")
    }

    @Test func theFactoryPicksTheRightClientPerProvider() {
        #expect(LLMClientFactory.make(provider: .anthropic, key: "k", model: "m")
                is AnthropicClient)
        #expect(LLMClientFactory.make(provider: .openai, key: "k", model: "m")
                is OpenAICompatibleClient)
        #expect(LLMClientFactory.make(provider: .openrouter, key: "k", model: "m")
                is OpenAICompatibleClient)
    }

}

struct RequestBodyTests {

    private func body(_ request: URLRequest) throws -> [String: Any] {
        let data = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    @Test func openAICarriesTheTokenLimit() throws {
        let client = OpenAICompatibleClient(apiKey: "k", model: "m",
                                            baseURL: Provider.openai.baseURL)
        let tuned = try body(client.chatRequest(system: "s", user: "u",
                                                maxTokens: 512, stream: true, tuned: true))
        #expect(tuned["max_completion_tokens"] as? Int == 512)
        #expect(tuned["stream"] as? Bool == true)

        let plain = try body(client.chatRequest(system: "s", user: "u",
                                                maxTokens: 512, stream: false, tuned: false))
        #expect(plain["max_completion_tokens"] == nil)
        #expect(plain["max_tokens"] == nil)
        #expect(plain["model"] as? String == "m")
    }

    @Test func anthropicKeepsItsLimitOnBothAttempts() throws {
        let client = AnthropicClient(apiKey: "k", model: "m")
        let tuned = try body(client.messagesRequest(system: "s", user: "u",
                                                    maxTokens: 512, stream: true, tuned: true))
        #expect(tuned["max_tokens"] as? Int == 512)
        #expect(tuned["output_config"] != nil)

        let plain = try body(client.messagesRequest(system: "s", user: "u",
                                                    maxTokens: 512, stream: true, tuned: false))
        #expect(plain["max_tokens"] as? Int == 512)
        #expect(plain["output_config"] == nil)
    }
}
