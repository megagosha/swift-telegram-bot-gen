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
                    // Advance offset past failed updates to avoid infinite retry loop.
                    // Fetch raw JSON and extract the highest update_id.
                    await self.skipFailedUpdates()
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
            let raw: RawUpdatesResponse = try await client.post("getUpdates", params: params)
            if let maxId = raw.result?.map(\.updateId).max() {
                offset = maxId + 1
                logger.warning("Skipped updates up to \(maxId) due to decode failure")
            }
        } catch {
            logger.error("Failed to skip updates: \(String(describing: error))")
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s backoff
        }
    }
}

/// Minimal type to extract update_id from raw getUpdates responses
/// without decoding the full TGUpdate structure.
private struct RawUpdatesResponse: Decodable, Sendable {
    let result: [RawUpdate]?
}

private struct RawUpdate: Decodable, Sendable {
    let updateId: Int

    private enum CodingKeys: String, CodingKey {
        case updateId = "update_id"
    }
}
