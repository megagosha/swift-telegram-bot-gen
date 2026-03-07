import Testing
import TGBotAPI
@testable import TGBot

@Suite
struct TGMessageHandlerTests {
    @Test func shouldProcessReturnsTrueForMessageUpdate() {
        let handler = TGMessageHandler { _, _ in }
        let update = TGUpdateFixtures.withMessage(text: "hello")
        #expect(handler.shouldProcess(update))
    }

    @Test func shouldProcessReturnsFalseForNonMessageUpdate() {
        let handler = TGMessageHandler { _, _ in }
        let update = TGUpdateFixtures.empty()
        #expect(!handler.shouldProcess(update))
    }

    @Test func shouldProcessReturnsFalseForCallbackQueryUpdate() {
        let handler = TGMessageHandler { _, _ in }
        let update = TGUpdateFixtures.withCallbackQuery()
        #expect(!handler.shouldProcess(update))
    }

    @Test func handleInvokesCallbackWithCorrectMessage() async throws {
        let client = MockBotClient()
        let receivedText = SendableBox<String?>(nil)
        let handler = TGMessageHandler { msg, _ in
            receivedText.set(msg.text)
        }
        let update = TGUpdateFixtures.withMessage(text: "test message")
        try await handler.handle(update, client: client)
        #expect(receivedText.value == "test message")
    }
}
