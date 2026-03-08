import Foundation
import os
import TGBotAPI

actor TGLongPoller {
    private let client: TGBotClient
    private let config: TGLongPollingConfig
    private var offset: Int?
    private var task: Task<Void, Never>?
    private let logger = Logger(subsystem: "TGBot", category: "LongPoller")

    init(client: TGBotClient, config: TGLongPollingConfig) {
        self.client = client
        self.config = config
    }

    func start() -> AsyncStream<TGUpdate> {
        let (stream, continuation) = AsyncStream<TGUpdate>.makeStream()
        task = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                do {
                    let currentOffset = await self.offset
                    let params = TGGetUpdatesParams(
                        offset: currentOffset,
                        limit: self.config.limit,
                        timeout: self.config.timeout,
                        allowedUpdates: self.config.allowedUpdates
                    )
                    let updates: [TGUpdate] = try await self.client.post("getUpdates", params: params)
                    for update in updates {
                        continuation.yield(update)
                    }
                    if let last = updates.last {
                        await self.setOffset(last.updateId + 1)
                    }
                } catch is CancellationError {
                    break
                } catch {
                    self.logger.error("Polling error: \(String(describing: error))")
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
                }
            }
            continuation.finish()
        }
        return stream
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func setOffset(_ value: Int) {
        offset = value
    }
}
