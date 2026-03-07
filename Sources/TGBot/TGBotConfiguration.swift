import Foundation

public struct TGBotConfiguration: Sendable {
    public let minRequestInterval: TimeInterval
    public let pollingConfig: TGLongPollingConfig

    public init(minRequestInterval: TimeInterval = 0.05,
                pollingConfig: TGLongPollingConfig = .default) {
        self.minRequestInterval = minRequestInterval
        self.pollingConfig = pollingConfig
    }

    public static let `default` = TGBotConfiguration()
}

public struct TGLongPollingConfig: Sendable {
    public let timeout: Int
    public let limit: Int?
    public let allowedUpdates: [String]?

    public init(timeout: Int = 30, limit: Int? = nil, allowedUpdates: [String]? = nil) {
        self.timeout = timeout
        self.limit = limit
        self.allowedUpdates = allowedUpdates
    }

    public static let `default` = TGLongPollingConfig()
}
