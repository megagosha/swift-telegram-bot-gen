import Foundation

public enum TGBotError: Error, Sendable {
    case apiError(code: Int, description: String)
    case missingResult
    case invalidResponse
}
