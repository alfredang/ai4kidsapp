import Foundation

/// Thin client for the DeepSeek chat-completions API (OpenAI format). Used only
/// by the parent-unlocked AI Workshops, with the parent's own key — the app
/// ships no key and runs no server. Only the workshop chat text is sent.
struct DeepSeekClient: Sendable {
    struct Message: Codable, Sendable, Equatable {
        let role: String   // "system" | "user" | "assistant"
        let content: String
    }

    enum Failure: Error, Sendable, Equatable {
        case badKey          // 401 / 403
        case noCredit        // 402
        case busy            // 429 / 5xx
        case offline         // transport error
        case unexpected
    }

    static let baseURL = URL(string: "https://api.deepseek.com")!
    static let model = "deepseek-flash"

    let apiKey: String

    /// Cheap authenticated call used to validate a pasted key.
    func checkKey() async -> Result<Void, Failure> {
        var request = URLRequest(url: Self.baseURL.appending(path: "models"), timeoutInterval: 15)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        switch await send(request) {
        case .success: return .success(())
        case .failure(let failure): return .failure(failure)
        }
    }

    /// Sends the conversation and returns the assistant's reply text.
    func chat(_ messages: [Message], maxTokens: Int = 700) async -> Result<String, Failure> {
        struct Body: Encodable {
            struct Thinking: Encodable { let type: String }
            let model: String
            let messages: [Message]
            let thinking: Thinking
            let max_tokens: Int
            let temperature: Double
            let stream: Bool
        }
        struct Reply: Decodable {
            struct Choice: Decodable { let message: Message }
            let choices: [Choice]
        }

        var request = URLRequest(url: Self.baseURL.appending(path: "chat/completions"), timeoutInterval: 45)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(Body(
            model: Self.model, messages: messages, thinking: .init(type: "disabled"),
            max_tokens: maxTokens, temperature: 0.8, stream: false))

        switch await send(request) {
        case .failure(let failure):
            return .failure(failure)
        case .success(let data):
            guard let reply = try? JSONDecoder().decode(Reply.self, from: data),
                  let text = reply.choices.first?.message.content
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty
            else { return .failure(.unexpected) }
            return .success(text)
        }
    }

    private func send(_ request: URLRequest) async -> Result<Data, Failure> {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            switch (response as? HTTPURLResponse)?.statusCode ?? 0 {
            case 200..<300: return .success(data)
            case 401, 403:  return .failure(.badKey)
            case 402:       return .failure(.noCredit)
            case 429, 500..<600: return .failure(.busy)
            default:        return .failure(.unexpected)
            }
        } catch {
            return .failure(.offline)
        }
    }
}
