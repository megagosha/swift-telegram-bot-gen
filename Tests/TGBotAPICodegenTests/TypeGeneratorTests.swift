import XCTest
@testable import TGBotAPICodegenLib

final class TypeGeneratorTests: XCTestCase {

    let userType = APIType(
        name: "User",
        href: "https://core.telegram.org/bots/api#user",
        description: ["This object represents a Telegram user or bot."],
        fields: [
            APIField(name: "id", types: ["Integer"], required: true, description: "Unique identifier"),
            APIField(name: "is_bot", types: ["Boolean"], required: true, description: "True if this user is a bot"),
            APIField(name: "first_name", types: ["String"], required: true, description: "User's first name"),
            APIField(name: "last_name", types: ["String"], required: false, description: "Optional. User's last name"),
        ],
        subtypes: nil,
        subtypeOf: nil
    )

    func testStructGeneration() {
        let code = TypeGenerator.generateStruct(type: userType, unionEnums: [:]).joined(separator: "\n")
        XCTAssertTrue(code.contains("TGUser"), "Should have TG prefix")
        XCTAssertTrue(code.contains("Codable"), "Should be Codable")
        XCTAssertTrue(code.contains("Sendable"), "Should be Sendable")
        XCTAssertTrue(code.contains("struct"), "Should be a struct")
    }

    func testCodingKeys() {
        let code = TypeGenerator.generateStruct(type: userType, unionEnums: [:]).joined(separator: "\n")
        XCTAssertTrue(code.contains("CodingKeys"), "Should have CodingKeys")
        XCTAssertTrue(code.contains("is_bot"), "Should map is_bot")
        XCTAssertTrue(code.contains("first_name"), "Should map first_name")
    }

    func testOptionalFields() {
        let code = TypeGenerator.generateStruct(type: userType, unionEnums: [:]).joined(separator: "\n")
        XCTAssertTrue(code.contains("lastName: String?"), "last_name should be optional")
        XCTAssertFalse(code.contains("firstName: String?"), "first_name should not be optional")
    }

    func testPublicInit() {
        let code = TypeGenerator.generateStruct(type: userType, unionEnums: [:]).joined(separator: "\n")
        XCTAssertTrue(code.contains("public init("), "Should have public init")
        XCTAssertTrue(code.contains("lastName: String? = nil"), "Optional param should default to nil")
    }

    func testAbstractEnumGeneration() {
        let parentType = APIType(
            name: "MessageOrigin",
            href: "https://example.com",
            description: ["Abstract type"],
            fields: nil,
            subtypes: ["MessageOriginUser", "MessageOriginChat"],
            subtypeOf: nil
        )
        let messageOriginUser = APIType(
            name: "MessageOriginUser",
            href: "https://example.com",
            description: [],
            fields: [APIField(name: "type", types: ["String"], required: true, description: "Type of the message origin, always \"user\"")],
            subtypes: nil,
            subtypeOf: ["MessageOrigin"]
        )
        let messageOriginChat = APIType(
            name: "MessageOriginChat",
            href: "https://example.com",
            description: [],
            fields: [APIField(name: "type", types: ["String"], required: true, description: "Type of the message origin, always \"chat\"")],
            subtypes: nil,
            subtypeOf: ["MessageOrigin"]
        )
        let types: [String: APIType] = [
            "MessageOrigin": parentType,
            "MessageOriginUser": messageOriginUser,
            "MessageOriginChat": messageOriginChat,
        ]
        let code = TypeGenerator.generateAbstractEnum(type: parentType, types: types, unionEnums: [:]).joined(separator: "\n")
        XCTAssertTrue(code.contains("enum TGMessageOrigin"), "Should be an enum")
        XCTAssertTrue(code.contains("Codable"), "Should be Codable")
        XCTAssertTrue(code.contains("\"user\""), "Should have discriminator value")
        XCTAssertTrue(code.contains("\"chat\""), "Should have chat discriminator")
    }
}
