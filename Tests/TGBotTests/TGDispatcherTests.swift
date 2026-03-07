import Testing
import TGBotAPI
@testable import TGBot

@Suite
struct TGDispatcherTests {
    @Test func allMatchingHandlersCalled() async {
        let client = MockBotClient()
        let called1 = SendableBox(false)
        let called2 = SendableBox(false)
        let h1 = TGMessageHandler { _, _ in called1.set(true) }
        let h2 = TGMessageHandler { _, _ in called2.set(true) }
        let dispatcher = TGDispatcher(handlers: [h1, h2])

        let update = TGUpdateFixtures.withMessage(text: "hi")
        await dispatcher.process(update, client: client)

        #expect(called1.value)
        #expect(called2.value)
    }

    @Test func nonMatchingHandlersSkipped() async {
        let client = MockBotClient()
        let msgCalled = SendableBox(false)
        let cbCalled = SendableBox(false)
        let msgHandler = TGMessageHandler { _, _ in msgCalled.set(true) }
        let cbHandler = TGCallbackQueryHandler { _, _ in cbCalled.set(true) }
        let dispatcher = TGDispatcher(handlers: [msgHandler, cbHandler])

        let update = TGUpdateFixtures.withMessage(text: "hi")
        await dispatcher.process(update, client: client)

        #expect(msgCalled.value)
        #expect(!cbCalled.value)
    }

    @Test func errorInHandlerDoesNotAbortRemainingHandlers() async {
        let client = MockBotClient()
        let secondCalled = SendableBox(false)

        struct TestError: Error {}
        let h1 = TGMessageHandler { _, _ in throw TestError() }
        let h2 = TGMessageHandler { _, _ in secondCalled.set(true) }
        let dispatcher = TGDispatcher(handlers: [h1, h2])

        let update = TGUpdateFixtures.withMessage(text: "hi")
        await dispatcher.process(update, client: client)

        #expect(secondCalled.value)
    }
}
