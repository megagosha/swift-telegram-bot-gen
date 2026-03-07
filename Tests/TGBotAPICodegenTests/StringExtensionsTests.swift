import XCTest
@testable import TGBotAPICodegenLib

final class StringExtensionsTests: XCTestCase {
    func testSnakeToCamelCase() {
        XCTAssertEqual("chat_id".snakeToCamelCase, "chatId")
        XCTAssertEqual("is_bot".snakeToCamelCase, "isBot")
        XCTAssertEqual("first_name".snakeToCamelCase, "firstName")
        XCTAssertEqual("id".snakeToCamelCase, "id")
        XCTAssertEqual("message_id".snakeToCamelCase, "messageId")
        XCTAssertEqual("reply_to_message".snakeToCamelCase, "replyToMessage")
    }

    func testCapitalizedFirst() {
        XCTAssertEqual("hello".capitalizedFirst, "Hello")
        XCTAssertEqual("Hello".capitalizedFirst, "Hello")
        XCTAssertEqual("".capitalizedFirst, "")
    }

    func testAsDocComment() {
        let result = "Some description".asDocComment(indent: "    ")
        XCTAssertEqual(result, "    /// Some description")
    }
}
