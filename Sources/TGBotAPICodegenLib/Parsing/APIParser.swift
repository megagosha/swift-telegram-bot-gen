import Foundation

// MARK: - Simple DOM node (lightweight, for internal use)

/// A minimal DOM node used while traversing the token stream.
struct SimpleNode: Sendable {
    var tag: String              // lowercase tag name; "" for text nodes
    var attrs: [String: String]
    var rawText: String          // content for text nodes
    var children: [SimpleNode]

    init(tag: String, attrs: [String: String] = [:]) {
        self.tag = tag; self.attrs = attrs; self.rawText = ""; self.children = []
    }

    init(text: String) {
        self.tag = ""; self.attrs = [:]; self.rawText = text; self.children = []
    }

    /// All text (including inside children), with <br> → "\n" and <img alt> inlined.
    var allText: String {
        if tag.isEmpty { return rawText }
        if tag == "br" { return "\n" }
        if tag == "img" { return attrs["alt"] ?? "" }
        return children.map(\.allText).joined()
    }

    /// Depth-first search for first element matching tag.
    func first(_ tag: String) -> SimpleNode? {
        if self.tag == tag { return self }
        for child in children {
            if let found = child.first(tag) { return found }
        }
        return nil
    }

    /// Collect all elements matching tag (depth-first).
    func all(_ tag: String) -> [SimpleNode] {
        var result: [SimpleNode] = []
        if self.tag == tag { result.append(self) }
        for child in children { result += child.all(tag) }
        return result
    }

    /// Direct children with the given tag.
    func directChildren(_ tag: String) -> [SimpleNode] {
        children.filter { $0.tag == tag }
    }
}

// MARK: - Token cursor

private struct TokenCursor: Sendable {
    let tokens: [HTMLToken]
    var index: Int

    var isAtEnd: Bool { index >= tokens.count }

    mutating func peek() -> HTMLToken? {
        guard !isAtEnd else { return nil }
        return tokens[index]
    }

    @discardableResult
    mutating func advance() -> HTMLToken? {
        guard !isAtEnd else { return nil }
        defer { index += 1 }
        return tokens[index]
    }

    /// Consume tokens until (exclusive) the named closing tag, building a SimpleNode tree.
    /// Depth tracks nesting of the same tag name.
    mutating func collectSubtree(openTag: String, attrs: [String: String]) -> SimpleNode {
        var node = SimpleNode(tag: openTag, attrs: attrs)
        collectChildren(into: &node, closingTag: openTag)
        return node
    }

    mutating func collectChildren(into parent: inout SimpleNode, closingTag: String) {
        var depth = 1
        while !isAtEnd {
            guard let tok = advance() else { break }
            switch tok {
            case .text(let t):
                parent.children.append(SimpleNode(text: t))

            case .openTag(let name, let a):
                if name == closingTag { depth += 1 }
                let voidTags = ["area","base","br","col","embed","hr","img","input",
                                "link","meta","param","source","track","wbr"]
                if voidTags.contains(name) {
                    parent.children.append(SimpleNode(tag: name, attrs: a))
                } else {
                    var child = SimpleNode(tag: name, attrs: a)
                    collectChildren(into: &child, closingTag: name)
                    parent.children.append(child)
                }
                if name == closingTag { depth -= 1; if depth == 0 { return } }

            case .selfClosingTag(let name, let a):
                parent.children.append(SimpleNode(tag: name, attrs: a))

            case .closeTag(let name):
                if name == closingTag {
                    depth -= 1
                    if depth == 0 { return }
                }
            }
        }
    }
}

// MARK: - APIParser

public enum APIParser {
    public static func parse(html: String) throws -> APISpec {
        let tokens = HTMLTokenizer.tokenize(html)
        var cursor = TokenCursor(tokens: tokens, index: 0)

        // Find <div id="dev_page_content">
        guard let devDiv = findDevPageContent(&cursor) else {
            throw ParseError.missingDevPageContent
        }

        return try extractSpec(from: devDiv)
    }

    // MARK: – Find dev_page_content div

    private static func findDevPageContent(_ cursor: inout TokenCursor) -> SimpleNode? {
        while !cursor.isAtEnd {
            guard let tok = cursor.advance() else { break }
            if case .openTag(let name, let attrs) = tok,
               name == "div",
               attrs["id"] == "dev_page_content" {
                return cursor.collectSubtree(openTag: "div", attrs: attrs)
            }
        }
        return nil
    }

    // MARK: – Extract spec from the div

    private static func extractSpec(from div: SimpleNode) throws -> APISpec {
        // Direct children (skip text nodes)
        let children = div.children

        // First <h4> → release date / changelog
        guard let firstH4 = div.first("h4") else { throw ParseError.missingReleaseHeader }
        let releaseDate = cleanDescriptionText(firstH4.allText)
        let changelog: String
        if let aNode = firstH4.first("a"), let href = aNode.attrs["href"] {
            changelog = href.hasPrefix("http") ? href : "https://core.telegram.org/bots/api" + href
        } else {
            changelog = ""
        }

        // First direct <p> → version string
        let version: String
        if let pNode = div.directChildren("p").first {
            version = pNode.allText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else if let pNode = div.first("p") {
            version = pNode.allText.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            version = ""
        }

        var methods: [String: APIMethod] = [:]
        var types: [String: APIType] = [:]

        var currName = ""
        var currKind = ""   // "types" or "methods"

        // Iterate direct children
        for child in children {
            let tag = child.tag

            if tag == "h3" || tag == "hr" {
                currName = ""; currKind = ""
                continue
            }

            if tag == "h4" {
                // Find <a name="...">
                guard let anchor = child.first("a"), let anchorName = anchor.attrs["name"] else {
                    currName = ""; currKind = ""
                    continue
                }
                if anchorName.contains("-") {
                    currName = ""; currKind = ""
                    continue
                }
                let itemName = child.allText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !itemName.isEmpty else { currName = ""; currKind = ""; continue }

                let href: String
                if let hrefAttr = anchor.attrs["href"] {
                    href = hrefAttr.hasPrefix("http") ? hrefAttr : "https://core.telegram.org/bots/api" + hrefAttr
                } else {
                    href = ""
                }

                if let firstChar = itemName.first, firstChar.isUppercase {
                    currKind = "types"
                    currName = itemName
                    types[currName] = APIType(
                        name: currName, href: href,
                        description: [], fields: nil, subtypes: nil, subtypeOf: nil
                    )
                } else {
                    currKind = "methods"
                    currName = itemName
                    methods[currName] = APIMethod(
                        name: currName, href: href,
                        description: [], returns: [], fields: nil
                    )
                }
                continue
            }

            guard !currName.isEmpty, !currKind.isEmpty else { continue }

            if tag == "p" {
                let lines = extractDescription(from: child)
                if currKind == "types" {
                    let existing = types[currName]!
                    types[currName] = existing.appendingDescription(lines)
                } else {
                    let existing = methods[currName]!
                    methods[currName] = existing.appendingDescription(lines)
                }
            }

            if tag == "table" {
                let fields = extractFields(from: child, kind: currKind)
                if currKind == "types" {
                    let existing = types[currName]!
                    types[currName] = existing.withFields(fields)
                } else {
                    let existing = methods[currName]!
                    methods[currName] = existing.withFields(fields)
                }
            }

            if tag == "ul" && currName != "InputFile" {
                let subtypeList = extractListItems(from: child)
                if currKind == "types" {
                    let existing = types[currName]!
                    let bullets = subtypeList.map { "- \($0)" }
                    types[currName] = existing.withSubtypes(subtypeList).appendingDescription(bullets)
                } else {
                    let bullets = subtypeList.map { "- \($0)" }
                    let existing = methods[currName]!
                    methods[currName] = existing.appendingDescription(bullets)
                }
            }

            // Update return types for methods after each description addition
            if currKind == "methods", let m = methods[currName], !m.description.isEmpty {
                let rets = extractReturnTypes(from: m.description)
                if !rets.isEmpty {
                    methods[currName] = m.withReturns(rets)
                }
            }
        }

        // Set subtype_of reverse links
        for (typeName, typeInfo) in types {
            for subtype in (typeInfo.subtypes ?? []) {
                if types[subtype] != nil {
                    let existing = types[subtype]!
                    if !(existing.subtypeOf ?? []).contains(typeName) {
                        types[subtype] = existing.appendingSubtypeOf(typeName)
                    }
                }
            }
        }

        return APISpec(
            version: version,
            releaseDate: releaseDate,
            changelog: changelog,
            methods: methods,
            types: types
        )
    }

    // MARK: – Field extraction

    private static func extractFields(from table: SimpleNode, kind: String) -> [APIField] {
        guard let tbody = table.first("tbody") else { return [] }
        var fields: [APIField] = []
        for tr in tbody.directChildren("tr") {
            let cells = tr.directChildren("td")
            if kind == "types" && cells.count == 3 {
                let desc = cells[2].allText.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanedDesc = cleanDescriptionText(desc)
                fields.append(APIField(
                    name: cells[0].allText.trimmingCharacters(in: .whitespacesAndNewlines),
                    types: cleanTGType(cells[1].allText.trimmingCharacters(in: .whitespacesAndNewlines)),
                    required: !cleanedDesc.hasPrefix("Optional. "),
                    description: cleanedDesc
                ))
            } else if kind == "methods" && cells.count == 4 {
                let requiredText = cells[2].allText.trimmingCharacters(in: .whitespacesAndNewlines)
                let desc = cleanDescriptionText(cells[3].allText.trimmingCharacters(in: .whitespacesAndNewlines))
                fields.append(APIField(
                    name: cells[0].allText.trimmingCharacters(in: .whitespacesAndNewlines),
                    types: cleanTGType(cells[1].allText.trimmingCharacters(in: .whitespacesAndNewlines)),
                    required: requiredText == "Yes",
                    description: desc
                ))
            }
        }
        return fields
    }

    private static func extractListItems(from ul: SimpleNode) -> [String] {
        ul.directChildren("li").map { li in
            cleanDescriptionText(li.allText.trimmingCharacters(in: .whitespacesAndNewlines))
        }.filter { !$0.isEmpty }
    }

    private static func extractDescription(from node: SimpleNode) -> [String] {
        let text = descriptionText(from: node)
        return cleanTGDescriptionText(text).filter { !$0.isEmpty }
    }

    /// Produces a plain-text representation of a node, handling img alt and br.
    private static func descriptionText(from node: SimpleNode) -> String {
        node.allText
    }

    private static func cleanDescriptionText(_ text: String) -> String {
        cleanTGDescriptionText(text).joined(separator: " ")
    }

    // MARK: – Return type extraction

    private static func extractReturnTypes(from descLines: [String]) -> [String] {
        let description = descLines.joined(separator: "\n")

        // Pattern 1: "on success, X"
        if let range = description.range(of: #"(?i)on success[, ]+([^.]+)"#, options: .regularExpression) {
            let group = extractGroup1(from: description, pattern: #"(?i)on success[, ]+([^.]+)"#)
            if let g = group { return parseReturnString(g.trimmingCharacters(in: .whitespacesAndNewlines)) }
        }

        // Pattern 2: "returns X [on success]"
        if let group = extractGroup1(from: description, pattern: #"(?i)returns ([^.]+?)(?:\s+on success)?\."#) {
            return parseReturnString(group.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Pattern 3: "X is returned"
        if let group = extractGroup1(from: description, pattern: #"(?i)([^.]+?)\s+is returned"#) {
            return parseReturnString(group.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        // Fallback: simpler "returns X" without period requirement
        if let group = extractGroup1(from: description, pattern: #"(?i)returns ([^.\n]+)"#) {
            return parseReturnString(group.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return []
    }

    private static func extractGroup1(from text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1 else { return nil }
        let groupRange = match.range(at: 1)
        guard groupRange.location != NSNotFound else { return nil }
        return ns.substring(with: groupRange)
    }

    private static func parseReturnString(_ ret: String) -> [String] {
        // Check for "Array of X"
        let arrayPattern = #"(?i)(?:array of )+(\w+)"#
        if let match = extractGroup1(from: ret, pattern: arrayPattern) {
            return cleanTGType(match).map { "Array of \($0)" }
        }
        // Split on spaces and take capitalised words
        let punct = CharacterSet.punctuationCharacters
        let words = ret.components(separatedBy: .whitespaces).filter { word in
            guard let first = word.first else { return false }
            return first.isUppercase
        }
        return words
            .map { $0.unicodeScalars.filter { !punct.contains($0) }.map { String($0) }.joined() }
            .flatMap { cleanTGType($0) }
            .filter { !$0.isEmpty }
    }

    enum ParseError: Error {
        case missingDevPageContent
        case missingReleaseHeader
    }
}

// MARK: - APIType / APIMethod mutation helpers (value-type builders)

extension APIType {
    func appendingDescription(_ lines: [String]) -> APIType {
        APIType(name: name, href: href, description: description + lines,
                fields: fields, subtypes: subtypes, subtypeOf: subtypeOf)
    }
    func withFields(_ f: [APIField]) -> APIType {
        APIType(name: name, href: href, description: description,
                fields: f, subtypes: subtypes, subtypeOf: subtypeOf)
    }
    func withSubtypes(_ s: [String]) -> APIType {
        APIType(name: name, href: href, description: description,
                fields: fields, subtypes: s, subtypeOf: subtypeOf)
    }
    func appendingSubtypeOf(_ parent: String) -> APIType {
        let existing = subtypeOf ?? []
        return APIType(name: name, href: href, description: description,
                       fields: fields, subtypes: subtypes, subtypeOf: existing + [parent])
    }
}

extension APIMethod {
    func appendingDescription(_ lines: [String]) -> APIMethod {
        APIMethod(name: name, href: href, description: description + lines,
                  returns: returns, fields: fields)
    }
    func withFields(_ f: [APIField]) -> APIMethod {
        APIMethod(name: name, href: href, description: description,
                  returns: returns, fields: f)
    }
    func withReturns(_ r: [String]) -> APIMethod {
        APIMethod(name: name, href: href, description: description,
                  returns: r, fields: fields)
    }
}
