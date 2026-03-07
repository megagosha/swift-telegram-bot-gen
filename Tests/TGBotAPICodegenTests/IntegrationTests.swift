import XCTest
@testable import TGBotAPICodegenLib
import Foundation

final class IntegrationTests: XCTestCase {

    // Path to the bundled api.json (relative to package root)
    static let apiJSONPath: String = {
        // Try to find api.json relative to this file's location
        let candidates = [
            // When running via `swift test` from the package directory
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()  // TGBotAPICodegenTests
                .deletingLastPathComponent()  // Tests
                .deletingLastPathComponent()  // package root
                .appendingPathComponent("Resources/api.json")
                .path,
        ]
        for path in candidates {
            if FileManager.default.fileExists(atPath: path) { return path }
        }
        return ""
    }()

    var spec: APISpec!

    override func setUpWithError() throws {
        let path = Self.apiJSONPath
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            throw XCTSkip("api.json not found at \(Self.apiJSONPath)")
        }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        spec = try JSONDecoder().decode(APISpec.self, from: data)
    }

    func testTypeCount() {
        XCTAssertGreaterThanOrEqual(spec.types.count, 280, "Should have at least 280 types")
    }

    func testMethodCount() {
        XCTAssertGreaterThanOrEqual(spec.methods.count, 160, "Should have at least 160 methods")
    }

    func testTGUserPresent() {
        XCTAssertNotNil(spec.types["User"], "User type should be present")
        let user = spec.types["User"]!
        XCTAssertFalse((user.fields ?? []).isEmpty, "User should have fields")
    }

    func testTGMessagePresent() {
        XCTAssertNotNil(spec.types["Message"], "Message type should be present")
    }

    func testTGUpdatePresent() {
        XCTAssertNotNil(spec.types["Update"], "Update type should be present")
    }

    func testTGMessageOriginIsAbstractType() {
        XCTAssertNotNil(spec.types["MessageOrigin"], "MessageOrigin should be present")
        let mo = spec.types["MessageOrigin"]!
        XCTAssertFalse((mo.subtypes ?? []).isEmpty, "MessageOrigin should have subtypes")
    }

    func testSendMessageMethodPresent() {
        XCTAssertNotNil(spec.methods["sendMessage"], "sendMessage should be present")
        let sm = spec.methods["sendMessage"]!
        XCTAssertFalse((sm.fields ?? []).isEmpty, "sendMessage should have fields")
    }

    func testCodeGeneration() throws {
        let path = Self.apiJSONPath
        guard !path.isEmpty else { throw XCTSkip("api.json not found") }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let outDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TGBotAPICodegenTest-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outDir) }

        try CodeGenerator.generate(from: data, outputDir: outDir)

        let typesFile = outDir.appendingPathComponent("TGBotAPITypes.swift")
        let methodsFile = outDir.appendingPathComponent("TGBotAPIMethods.swift")
        let versionFile = outDir.appendingPathComponent("TGBotAPIVersion.swift")

        XCTAssertTrue(FileManager.default.fileExists(atPath: typesFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: methodsFile.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: versionFile.path))

        let typesCode = try String(contentsOf: typesFile)
        let methodsCode = try String(contentsOf: methodsFile)

        // Key types present
        XCTAssertTrue(typesCode.contains("TGUser"), "TGUser should be in types")
        XCTAssertTrue(typesCode.contains("TGMessage"), "TGMessage should be in types")
        XCTAssertTrue(typesCode.contains("TGInputFile"), "TGInputFile should be in types")

        // MessageOrigin is an enum
        XCTAssertTrue(typesCode.contains("enum TGMessageOrigin"), "MessageOrigin should be enum")

        // Union enum present
        XCTAssertTrue(typesCode.contains("TGIntOrString") || typesCode.contains("Or"), "Union enum should be present")

        // Methods present
        XCTAssertTrue(methodsCode.contains("TGSendMessageParams"), "sendMessage params should exist")
        XCTAssertTrue(methodsCode.contains("TGGetUpdatesParams"), "getUpdates params should exist")
    }
}
