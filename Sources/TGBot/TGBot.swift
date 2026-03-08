import Foundation
import TGBotAPI

public actor TGBot {
    public let client: TGBotClient
    private let poller: TGLongPoller
    private let dispatcher: TGDispatcher

    public init(token: String,
                handlers: [any TGHandlerProtocol],
                config: TGBotConfiguration = .default) {
        self.client = TGBotClient(token: token, minInterval: config.minRequestInterval)
        self.poller = TGLongPoller(client: client, config: config.pollingConfig)
        self.dispatcher = TGDispatcher(handlers: handlers)
    }

    /// Starts the polling loop. Suspends until cancelled or `stop()` is called.
    public func run() async {
        let updates = await poller.start()
        for await update in updates {
            await dispatcher.process(update, client: client)
        }
    }

    public func stop() async {
        await poller.stop()
    }
}
