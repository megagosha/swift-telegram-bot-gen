import Foundation
@testable import TGBot

final class MockBotClient: TGBotClientProtocol, @unchecked Sendable {
    var calls: [(method: String, data: Data)] = []
    var nextResponse: Data = Data()

    func post<P: Encodable & Sendable, R: Decodable & Sendable>(
        _ method: String, params: P
    ) async throws -> R {
        let encoded = try JSONEncoder().encode(params)
        calls.append((method, encoded))
        return try JSONDecoder().decode(R.self, from: nextResponse)
    }
}
