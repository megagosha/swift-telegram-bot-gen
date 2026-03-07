import TGBotAPI
import os

final class TGDispatcher: Sendable {
    private let handlers: [any TGHandlerProtocol]
    private let logger = Logger(subsystem: "TGBot", category: "Dispatcher")

    init(handlers: [any TGHandlerProtocol]) {
        self.handlers = handlers
    }

    func process(_ update: TGUpdate, client: any TGBotClientProtocol) async {
        for handler in handlers where handler.shouldProcess(update) {
            do {
                try await handler.handle(update, client: client)
            } catch {
                logger.error("Handler error: \(error.localizedDescription)")
            }
        }
    }
}
