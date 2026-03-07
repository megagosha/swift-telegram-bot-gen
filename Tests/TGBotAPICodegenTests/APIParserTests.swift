import XCTest
@testable import TGBotAPICodegenLib

final class APIParserTests: XCTestCase {

    // Minimal synthetic HTML that mirrors the Telegram API page structure
    static let minimalHTML = """
    <!DOCTYPE html>
    <html>
    <body>
    <div id="dev_page_content">
      <h4><a name="march-1-2026" href="#march-1-2026">March 1, 2026</a></h4>
      <p>Bot API 9.5</p>
      <h3>Getting updates</h3>
      <h4><a name="update" href="#update">Update</a></h4>
      <p>This object represents an incoming update.</p>
      <table>
        <tbody>
          <tr>
            <td>update_id</td>
            <td>Integer</td>
            <td>The update's unique identifier.</td>
          </tr>
          <tr>
            <td>message</td>
            <td>Message</td>
            <td>Optional. New incoming message of any kind.</td>
          </tr>
        </tbody>
      </table>
      <h3>Available methods</h3>
      <h4><a name="getme" href="#getme">getMe</a></h4>
      <p>A simple method for testing your bot's authentication token. Returns basic information about the bot in form of a User object.</p>
    </div>
    </body>
    </html>
    """

    func testParseVersion() throws {
        let spec = try APIParser.parse(html: Self.minimalHTML)
        XCTAssertEqual(spec.version, "Bot API 9.5")
    }

    func testParseReleaseDate() throws {
        let spec = try APIParser.parse(html: Self.minimalHTML)
        XCTAssertTrue(spec.releaseDate.contains("2026"))
    }

    func testTypeExtraction() throws {
        let spec = try APIParser.parse(html: Self.minimalHTML)
        XCTAssertNotNil(spec.types["Update"])
    }

    func testTypeFields() throws {
        let spec = try APIParser.parse(html: Self.minimalHTML)
        let update = try XCTUnwrap(spec.types["Update"])
        let fields = try XCTUnwrap(update.fields)
        XCTAssertEqual(fields.count, 2)
        XCTAssertEqual(fields[0].name, "update_id")
        XCTAssertEqual(fields[0].types, ["Integer"])
        XCTAssertTrue(fields[0].required)
        XCTAssertEqual(fields[1].name, "message")
        XCTAssertFalse(fields[1].required)
    }

    func testMethodExtraction() throws {
        let spec = try APIParser.parse(html: Self.minimalHTML)
        XCTAssertNotNil(spec.methods["getMe"])
    }

    func testMethodReturnType() throws {
        let spec = try APIParser.parse(html: Self.minimalHTML)
        let getMe = try XCTUnwrap(spec.methods["getMe"])
        XCTAssertFalse(getMe.returns.isEmpty, "getMe should have a return type")
        // Should contain User
        XCTAssertTrue(getMe.returns.contains("User"), "getMe should return User but got \(getMe.returns)")
    }

    func testSectionBoundary() throws {
        let spec = try APIParser.parse(html: Self.minimalHTML)
        // "Update" is a type, "getMe" is a method — they should be in correct buckets
        XCTAssertNil(spec.methods["Update"])
        XCTAssertNil(spec.types["getMe"])
    }
}
