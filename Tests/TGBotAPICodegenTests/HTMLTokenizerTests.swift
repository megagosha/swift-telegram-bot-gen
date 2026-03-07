import XCTest
@testable import TGBotAPICodegenLib

final class HTMLTokenizerTests: XCTestCase {
    func testOpenAndCloseTag() {
        let tokens = HTMLTokenizer.tokenize("<p>hello</p>")
        XCTAssertEqual(tokens.count, 3)
        if case .openTag(let name, _) = tokens[0] { XCTAssertEqual(name, "p") }
        else { XCTFail("Expected openTag") }
        if case .text(let t) = tokens[1] { XCTAssertEqual(t, "hello") }
        else { XCTFail("Expected text") }
        if case .closeTag(let name) = tokens[2] { XCTAssertEqual(name, "p") }
        else { XCTFail("Expected closeTag") }
    }

    func testSelfClosingVoidTag() {
        let tokens = HTMLTokenizer.tokenize("<br>")
        XCTAssertEqual(tokens.count, 1)
        if case .selfClosingTag(let name, _) = tokens[0] { XCTAssertEqual(name, "br") }
        else { XCTFail("Expected selfClosingTag for br") }
    }

    func testExplicitSelfClosingTag() {
        let tokens = HTMLTokenizer.tokenize("<img src=\"foo.png\"/>")
        XCTAssertEqual(tokens.count, 1)
        if case .selfClosingTag(let name, let attrs) = tokens[0] {
            XCTAssertEqual(name, "img")
            XCTAssertEqual(attrs["src"], "foo.png")
        } else { XCTFail("Expected selfClosingTag for img") }
    }

    func testAttributes() {
        let tokens = HTMLTokenizer.tokenize("<a href=\"#test\" name=\"anchor\">text</a>")
        if case .openTag(let name, let attrs) = tokens[0] {
            XCTAssertEqual(name, "a")
            XCTAssertEqual(attrs["href"], "#test")
            XCTAssertEqual(attrs["name"], "anchor")
        } else { XCTFail("Expected openTag with attrs") }
    }

    func testEntityDecoding() {
        let tokens = HTMLTokenizer.tokenize("<p>&amp;&lt;&gt;&quot;</p>")
        if case .text(let t) = tokens[1] { XCTAssertEqual(t, "&<>\"") }
        else { XCTFail("Expected decoded entities") }
    }

    func testDecimalEntity() {
        let tokens = HTMLTokenizer.tokenize("<p>&#65;</p>")
        if case .text(let t) = tokens[1] { XCTAssertEqual(t, "A") }
        else { XCTFail("Expected &#65; to decode to A") }
    }

    func testHexEntity() {
        let tokens = HTMLTokenizer.tokenize("<p>&#x41;</p>")
        if case .text(let t) = tokens[1] { XCTAssertEqual(t, "A") }
        else { XCTFail("Expected &#x41; to decode to A") }
    }

    func testCommentIgnored() {
        let tokens = HTMLTokenizer.tokenize("<!-- comment --><p>hi</p>")
        // Comment should produce no token
        let nonComment = tokens.filter { if case .text(_) = $0 { return true }; if case .openTag(_,_) = $0 { return true }; return false }
        XCTAssertFalse(nonComment.isEmpty)
        // Should not have any text token containing "comment"
        for tok in tokens {
            if case .text(let t) = tok { XCTAssertFalse(t.contains("comment")) }
        }
    }

    func testNestedTags() {
        let tokens = HTMLTokenizer.tokenize("<div><p>text</p></div>")
        XCTAssertGreaterThanOrEqual(tokens.count, 4)
    }
}
