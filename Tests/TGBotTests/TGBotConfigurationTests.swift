import Testing
@testable import TGBot

@Suite
struct TGBotConfigurationTests {
    @Test func defaultConfigurationValues() {
        let config = TGBotConfiguration.default
        #expect(config.minRequestInterval == 0.05)
        #expect(config.pollingConfig.timeout == 30)
        #expect(config.pollingConfig.limit == nil)
        #expect(config.pollingConfig.allowedUpdates == nil)
    }

    @Test func customConfigurationValues() {
        let polling = TGLongPollingConfig(timeout: 60, limit: 100, allowedUpdates: ["message"])
        let config = TGBotConfiguration(minRequestInterval: 0.1, pollingConfig: polling)
        #expect(config.minRequestInterval == 0.1)
        #expect(config.pollingConfig.timeout == 60)
        #expect(config.pollingConfig.limit == 100)
        #expect(config.pollingConfig.allowedUpdates == ["message"])
    }
}
