import XCTest
@testable import TGBotAPICodegenLib

final class TypeCleanerTests: XCTestCase {
    func testSimpleType() {
        XCTAssertEqual(cleanTGType("String"), ["String"])
    }

    func testFloatNumber() {
        XCTAssertEqual(cleanTGType("Float number"), ["Float"])
    }

    func testIntNormalization() {
        XCTAssertEqual(cleanTGType("Int"), ["Integer"])
    }

    func testTrueToBoolean() {
        XCTAssertEqual(cleanTGType("True"), ["Boolean"])
        XCTAssertEqual(cleanTGType("Bool"), ["Boolean"])
    }

    func testMessagesToMessage() {
        XCTAssertEqual(cleanTGType("Messages"), ["Message"])
    }

    func testOrSplit() {
        XCTAssertEqual(cleanTGType("Integer or String"), ["Integer", "String"])
    }

    func testArrayOfOrSplit() {
        XCTAssertEqual(cleanTGType("Array of String or Integer"), ["Array of String", "Array of Integer"])
    }

    func testMessagesOrTrue() {
        XCTAssertEqual(cleanTGType("Messages or True"), ["Message", "Boolean"])
    }

    func testCommaSplit() {
        let result = cleanTGType("InlineKeyboardMarkup, ReplyKeyboardMarkup, ReplyKeyboardRemove, ForceReply")
        XCTAssertEqual(result, ["InlineKeyboardMarkup", "ReplyKeyboardMarkup", "ReplyKeyboardRemove", "ForceReply"])
    }
}
