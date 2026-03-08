import Foundation
import os
import TGBotAPI

actor TGLongPoller {
    private let client: TGBotClient
    private let config: TGLongPollingConfig
    private var offset: Int?
    private var task: Task<Void, Never>?
    private var consecutiveErrors = 0
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
                    await self.resetBackoff()
                    for update in updates {
                        continuation.yield(update)
                    }
                    if let last = updates.last {
                        await self.setOffset(last.updateId + 1)
                    }
                } catch is CancellationError {
                    break
                } catch let error as TGBotError {
                    self.logger.error("Polling error: \(String(describing: error))")
                    // Decode or API error — skip past bad updates
                    await self.skipFailedUpdates()
                } catch {
                    // Network error — backoff and retry
                    self.logger.error("Polling error: \(String(describing: error))")
                    await self.backoff()
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

    private func resetBackoff() {
        consecutiveErrors = 0
    }

    /// Exponential backoff: 1s, 2s, 4s, 8s, …, capped at 30s.
    private func backoff() async {
        consecutiveErrors += 1
        let delay = min(30.0, pow(2.0, Double(consecutiveErrors - 1)))
        logger.info("Retrying in \(Int(delay))s (attempt \(self.consecutiveErrors))")
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
    }

    /// Fetches raw getUpdates JSON and advances offset past the highest
    /// update_id, skipping updates that failed to decode as [TGUpdate].
    private func skipFailedUpdates() async {
        do {
            let params = TGGetUpdatesParams(
                offset: offset,
                limit: config.limit,
                timeout: 0,
                allowedUpdates: config.allowedUpdates
            )
            let raw: [RawUpdate] = try await client.post("getUpdates", params: params)
            if let maxId = raw.map(\.updateId).max() {
                offset = maxId + 1
                logger.warning("Skipped updates up to \(maxId) due to decode failure")
            }
        } catch {
            logger.error("Failed to skip updates: \(String(describing: error))")
            await backoff()
        }
    }
}

/// Minimal type to extract update_id without decoding the full TGUpdate.
private struct RawUpdate: Decodable, Sendable {
    let updateId: Int

    private enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
    }
}
