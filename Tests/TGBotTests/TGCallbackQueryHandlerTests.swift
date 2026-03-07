import Testing
import TGBotAPI
@testable import TGBot

@Suite
struct TGCallbackQueryHandlerTests {
    @Test func shouldProcessReturnsTrueForCallbackQuery() {
        let handler = TGCallbackQueryHandler { _, _ in }
        let update = TGUpdateFixtures.withCallbackQuery()
        #expect(handler.shouldProcess(update))
    }

    @Test func shouldProcessReturnsFalseForMessageUpdate() {
        let handler = TGCallbackQueryHandler { _, _ in }
        let update = TGUpdateFixtures.withMessage(text: "hello")
        #expect(!handler.shouldProcess(update))
    }

    @Test func shouldProcessReturnsFalseForEmptyUpdate() {
        let handler = TGCallbackQueryHandler { _, _ in }
        let update = TGUpdateFixtures.empty()
        #expect(!handler.shouldProcess(update))
    }

    @Test func handleFiresCallbackWithCorrectQuery() async throws {
        let client = MockBotClient()
        let receivedData = SendableBox<String?>(nil)
        let handler = TGCallbackQueryHandler { query, _ in
            receivedData.set(query.data)
        }
        let update = TGUpdateFixtures.withCallbackQuery(data: "btn_1")
        try await handler.handle(update, client: client)
        #expect(receivedData.value == "btn_1")
    }
}
