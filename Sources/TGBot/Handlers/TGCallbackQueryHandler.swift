import TGBotAPI

public struct TGCallbackQueryHandler: TGHandlerProtocol {
    public let callback: @Sendable (TGCallbackQuery, any TGBotClientProtocol) async throws -> Void

    public init(callback: @escaping @Sendable (TGCallbackQuery, any TGBotClientProtocol) async throws -> Void) {
        self.callback = callback
    }

    public func shouldProcess(_ update: TGUpdate) -> Bool {
        update.callbackQuery != nil
    }

    public func handle(_ update: TGUpdate, client: any TGBotClientProtocol) async throws {
        guard let query = update.callbackQuery else { return }
        try await callback(query, client)
    }
}
