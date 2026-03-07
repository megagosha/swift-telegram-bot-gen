import TGBotAPI

public struct TGCommandHandler: TGHandlerProtocol {
    public let command: String
    public let callback: @Sendable (TGMessage, any TGBotClientProtocol) async throws -> Void

    public init(command: String,
                callback: @escaping @Sendable (TGMessage, any TGBotClientProtocol) async throws -> Void) {
        self.command = command
        self.callback = callback
    }

    public func shouldProcess(_ update: TGUpdate) -> Bool {
        guard let text = update.message?.text else { return false }
        // Match "/command" or "/command@BotName" or "/command args"
        let trimmed = text.split(separator: " ", maxSplits: 1).first.map(String.init) ?? text
        let withoutMention = trimmed.split(separator: "@", maxSplits: 1).first.map(String.init) ?? trimmed
        return withoutMention == command
    }

    public func handle(_ update: TGUpdate, client: any TGBotClientProtocol) async throws {
        guard let message = update.message else { return }
        try await callback(message, client)
    }
}
