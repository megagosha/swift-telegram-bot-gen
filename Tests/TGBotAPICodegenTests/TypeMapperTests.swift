import XCTest
@testable import TGBotAPICodegenLib

final class TypeMapperTests: XCTestCase {
    func testPrimitives() {
        XCTAssertEqual(TypeMapper.swiftType(for: "Integer"), "Int")
        XCTAssertEqual(TypeMapper.swiftType(for: "Boolean"), "Bool")
        XCTAssertEqual(TypeMapper.swiftType(for: "String"), "String")
        XCTAssertEqual(TypeMapper.swiftType(for: "Float"), "Double")
    }

    func testArrayOf() {
        XCTAssertEqual(TypeMapper.swiftType(for: "Array of Integer"), "[Int]")
        XCTAssertEqual(TypeMapper.swiftType(for: "Array of String"), "[String]")
    }

    func testCustomType() {
        XCTAssertEqual(TypeMapper.swiftType(for: "User"), "TGUser")
        XCTAssertEqual(TypeMapper.swiftType(for: "Message"), "TGMessage")
    }

    func testArrayOfCustomType() {
        XCTAssertEqual(TypeMapper.swiftType(for: "Array of User"), "[TGUser]")
    }

    func testInputFile() {
        XCTAssertEqual(TypeMapper.swiftType(for: "InputFile"), "TGInputFile")
    }

    func testUnionKey() {
        let key = TypeMapper.unionKey(for: ["Integer", "String"])
        XCTAssertEqual(key, "Integer|String")
    }

    func testUnionEnumName() {
        let name = TypeMapper.unionEnumName(for: ["Integer", "String"])
        XCTAssertTrue(name.contains("Int"))
        XCTAssertTrue(name.contains("String"))
        XCTAssertTrue(name.hasPrefix("TG"))
    }
}
