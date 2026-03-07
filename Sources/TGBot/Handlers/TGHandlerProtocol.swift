import TGBotAPI

public protocol TGHandlerProtocol: Sendable {
    func shouldProcess(_ update: TGUpdate) -> Bool
    func handle(_ update: TGUpdate, client: any TGBotClientProtocol) async throws
}
