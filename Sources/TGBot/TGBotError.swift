import Foundation

public enum TGBotError: LocalizedError, Sendable {
    case apiError(code: Int, description: String)
    case missingResult
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .apiError(let code, let description):
            return "Telegram API error \(code): \(description)"
        case .missingResult:
            return "Telegram API returned ok but no result"
        case .invalidResponse:
            return "Invalid response URL"
        }
    }
}
