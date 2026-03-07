import Foundation

public protocol TGBotClientProtocol: Sendable {
    func post<Params: Encodable & Sendable, Response: Decodable & Sendable>(
        _ method: String, params: Params
    ) async throws -> Response
}
