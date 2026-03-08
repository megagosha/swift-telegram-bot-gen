import Foundation

public actor TGBotClient: TGBotClientProtocol {
    private let token: String
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var lastRequest: Date?
    private let minInterval: TimeInterval

    public init(token: String, minInterval: TimeInterval = 0.05) {
        self.token = token
        self.minInterval = minInterval
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
    }

    public func post<Params: Encodable & Sendable, Response: Decodable & Sendable>(
        _ method: String, params: Params
    ) async throws -> Response {
        await throttleIfNeeded()

        guard let url = URL(string: "https://api.telegram.org/bot\(token)/\(method)") else {
            throw TGBotError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(params)

        let (data, _) = try await session.data(for: request)
        lastRequest = Date()

        let container = try decoder.decode(TGContainer<Response>.self, from: data)
        guard container.ok else {
            throw TGBotError.apiError(
                code: container.errorCode ?? -1,
                description: container.description ?? "Unknown error"
            )
        }
        guard let result = container.result else {
            throw TGBotError.missingResult
        }
        return result
    }

    private func throttleIfNeeded() async {
        if let last = lastRequest {
            let elapsed = Date().timeIntervalSince(last)
            if elapsed < minInterval {
                try? await Task.sleep(nanoseconds: UInt64((minInterval - elapsed) * 1_000_000_000))
            }
        }
    }
}
