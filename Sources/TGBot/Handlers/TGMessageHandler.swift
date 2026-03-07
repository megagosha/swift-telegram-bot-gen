import TGBotAPI

public struct TGMessageHandler: TGHandlerProtocol {
    public let callback: @Sendable (TGMessage, any TGBotClientProtocol) async throws -> Void

    public init(callback: @escaping @Sendable (TGMessage, any TGBotClientProtocol) async throws -> Void) {
        self.callback = callback
    }

    public func shouldProcess(_ update: TGUpdate) -> Bool {
        update.message != nil
    }

    public func handle(_ update: TGUpdate, client: any TGBotClientProtocol) async throws {
        guard let message = update.message else { return }
        try await callback(message, client)
    }
}
