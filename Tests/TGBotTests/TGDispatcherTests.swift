import Testing
@testable import TGBot
import TGBotAPI

@Suite
struct TGDispatcherTests {
    @Test func allMatchingHandlersCalled() async {
        let client = MockBotClient()
        let called1 = SendableBox(false)
        let called2 = SendableBox(false)
        let handler1 = TGMessageHandler { _, _ in called1.set(true) }
        let handler2 = TGMessageHandler { _, _ in called2.set(true) }
        let dispatcher = TGDispatcher(handlers: [handler1, handler2])

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
        let failingHandler = TGMessageHandler { _, _ in throw TestError() }
        let passingHandler = TGMessageHandler { _, _ in secondCalled.set(true) }
        let dispatcher = TGDispatcher(handlers: [failingHandler, passingHandler])

        let update = TGUpdateFixtures.withMessage(text: "hi")
        await dispatcher.process(update, client: client)

        #expect(secondCalled.value)
    }
}
