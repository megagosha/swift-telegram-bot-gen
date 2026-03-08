import Foundation
import Testing
@testable import TGBot

@Suite
struct TGContainerTests {
    @Test func decodesSuccessfulResult() throws {
        let json = #"{"ok":true,"result":42}"#
        let container = try JSONDecoder().decode(TGContainer<Int>.self, from: Data(json.utf8))
        #expect(container.ok)
        #expect(container.result == 42)
        #expect(container.errorCode == nil)
        #expect(container.description == nil)
    }

    @Test func decodesErrorResponse() throws {
        let json = #"{"ok":false,"error_code":400,"description":"Bad Request"}"#
        let container = try JSONDecoder().decode(TGContainer<Int>.self, from: Data(json.utf8))
        #expect(!container.ok)
        #expect(container.result == nil)
        #expect(container.errorCode == 400)
        #expect(container.description == "Bad Request")
    }

    @Test func decodesArrayResult() throws {
        let json = #"{"ok":true,"result":[1,2,3]}"#
        let container = try JSONDecoder().decode(TGContainer<[Int]>.self, from: Data(json.utf8))
        #expect(container.ok)
        #expect(container.result == [1, 2, 3])
    }
}
