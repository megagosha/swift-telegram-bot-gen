import XCTest
@testable import TGBotAPICodegenLib

final class MethodGeneratorTests: XCTestCase {

    let sendMessageMethod = APIMethod(
        name: "sendMessage",
        href: "https://core.telegram.org/bots/api#sendmessage",
        description: ["Use this method to send text messages."],
        returns: ["Message"],
        fields: [
            APIField(name: "chat_id", types: ["Integer", "String"], required: true, description: "Unique identifier for the target chat"),
            APIField(name: "text", types: ["String"], required: true, description: "Text of the message"),
            APIField(name: "parse_mode", types: ["String"], required: false, description: "Optional. Mode for parsing entities"),
        ]
    )

    func testStructNameGeneration() {
        let unionEnums = [TypeMapper.unionKey(for: ["Integer", "String"]): TypeMapper.unionEnumName(for: ["Integer", "String"])]
        let code = MethodGenerator.generateMethodParams(method: sendMessageMethod, unionEnums: unionEnums).joined(separator: "\n")
        XCTAssertTrue(code.contains("TGSendMessageParams"), "Should have TGSendMessageParams name")
        XCTAssertTrue(code.contains("struct"), "Should be a struct")
        XCTAssertTrue(code.contains("Codable"), "Should be Codable")
        XCTAssertTrue(code.contains("Sendable"), "Should be Sendable")
    }

    func testFieldsPresent() {
        let unionEnums = [TypeMapper.unionKey(for: ["Integer", "String"]): TypeMapper.unionEnumName(for: ["Integer", "String"])]
        let code = MethodGenerator.generateMethodParams(method: sendMessageMethod, unionEnums: unionEnums).joined(separator: "\n")
        XCTAssertTrue(code.contains("chatId"), "Should have chatId field")
        XCTAssertTrue(code.contains("text"), "Should have text field")
        XCTAssertTrue(code.contains("parseMode"), "Should have parseMode field")
    }

    func testOptionalDefaultsToNil() {
        let unionEnums = [TypeMapper.unionKey(for: ["Integer", "String"]): TypeMapper.unionEnumName(for: ["Integer", "String"])]
        let code = MethodGenerator.generateMethodParams(method: sendMessageMethod, unionEnums: unionEnums).joined(separator: "\n")
        XCTAssertTrue(code.contains("parseMode: String? = nil"), "Optional should default to nil")
    }

    func testPublicInit() {
        let unionEnums = [TypeMapper.unionKey(for: ["Integer", "String"]): TypeMapper.unionEnumName(for: ["Integer", "String"])]
        let code = MethodGenerator.generateMethodParams(method: sendMessageMethod, unionEnums: unionEnums).joined(separator: "\n")
        XCTAssertTrue(code.contains("public init("), "Should have public init")
    }
}
