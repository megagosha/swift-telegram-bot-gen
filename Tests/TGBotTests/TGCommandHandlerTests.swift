import Testing
import TGBotAPI
@testable import TGBot

@Suite
struct TGCommandHandlerTests {
    @Test func shouldProcessMatchesExactCommand() {
        let handler = TGCommandHandler(command: "/start") { _, _ in }
        let update = TGUpdateFixtures.withMessage(text: "/start")
        #expect(handler.shouldProcess(update))
    }

    @Test func shouldProcessMatchesCommandWithBotMention() {
        let handler = TGCommandHandler(command: "/start") { _, _ in }
        let update = TGUpdateFixtures.withMessage(text: "/start@MyBot")
        #expect(handler.shouldProcess(update))
    }

    @Test func shouldProcessMatchesCommandWithArgs() {
        let handler = TGCommandHandler(command: "/start") { _, _ in }
        let update = TGUpdateFixtures.withMessage(text: "/start some args")
        #expect(handler.shouldProcess(update))
    }

    @Test func shouldProcessReturnsFalseForDifferentCommand() {
        let handler = TGCommandHandler(command: "/start") { _, _ in }
        let update = TGUpdateFixtures.withMessage(text: "/help")
        #expect(!handler.shouldProcess(update))
    }

    @Test func shouldProcessReturnsFalseForPlainText() {
        let handler = TGCommandHandler(command: "/start") { _, _ in }
        let update = TGUpdateFixtures.withMessage(text: "hello world")
        #expect(!handler.shouldProcess(update))
    }

    @Test func shouldProcessReturnsFalseForNoMessage() {
        let handler = TGCommandHandler(command: "/start") { _, _ in }
        let update = TGUpdateFixtures.empty()
        #expect(!handler.shouldProcess(update))
    }

    @Test func handleFiresCallback() async throws {
        let client = MockBotClient()
        let fired = SendableBox(false)
        let handler = TGCommandHandler(command: "/start") { _, _ in
            fired.set(true)
        }
        let update = TGUpdateFixtures.withMessage(text: "/start")
        try await handler.handle(update, client: client)
        #expect(fired.value)
    }
}
