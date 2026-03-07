// Mirrors scrape.py's clean_tg_type() and get_proper_type() functions.
import Foundation

/// Normalises a Telegram type name to the canonical form used in api.json.
public func getProperType(_ t: String) -> String {
    switch t {
    case "Messages":    return "Message"
    case "Float number": return "Float"
    case "Int":         return "Integer"
    case "True", "Bool": return "Boolean"
    default:            return t
    }
}

/// Splits a Telegram type string (possibly a union or array) into an array of canonical type names.
///
/// Examples:
///   "Array of String or Integer" → ["Array of String", "Array of Integer"]
///   "Integer or String"          → ["Integer", "String"]
///   "Float number"               → ["Float"]
///   "Messages or True"           → ["Message", "Boolean"]
public func cleanTGType(_ t: String) -> [String] {
    var t = t.trimmingCharacters(in: .whitespaces)
    var prefix = ""
    if t.hasPrefix("Array of ") {
        prefix = "Array of "
        t = String(t.dropFirst("Array of ".count))
    }

    let parts = t
        .components(separatedBy: " or ")
        .flatMap { $0.components(separatedBy: " and ") }
        .flatMap { $0.components(separatedBy: ", ") }
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }

    return parts.map { prefix + getProperType($0) }
}

/// Cleans description text (mirrors scrape.py's clean_tg_description).
/// Replaces Unicode typographic characters and collapses whitespace.
public func cleanTGDescriptionText(_ text: String) -> [String] {
    var t = text
    t = t.replacingOccurrences(of: "\u{201C}", with: "\"")  // "
    t = t.replacingOccurrences(of: "\u{201D}", with: "\"")  // "
    t = t.replacingOccurrences(of: "\u{2026}", with: "...")  // …
    t = t.replacingOccurrences(of: "\u{2013}", with: "-")   // –
    t = t.replacingOccurrences(of: "\u{2014}", with: "-")   // —
    t = t.replacingOccurrences(of: "\u{2019}", with: "'")   // '

    // Collapse 2+ whitespace chars (except newlines) to one space
    var result = ""
    var prevWasSpace = false
    for ch in t {
        if ch == "\n" {
            result.append(ch)
            prevWasSpace = false
        } else if ch.isWhitespace {
            if !prevWasSpace { result.append(" ") }
            prevWasSpace = true
        } else {
            result.append(ch)
            prevWasSpace = false
        }
    }

    return result.components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespaces) }
        .filter { !$0.isEmpty }
}
