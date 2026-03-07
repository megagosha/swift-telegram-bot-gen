import Foundation

public enum HTMLToken: Sendable {
    case openTag(name: String, attributes: [String: String])
    case closeTag(name: String)
    case selfClosingTag(name: String, attributes: [String: String])
    case text(String)
}

/// A state-machine HTML tokenizer. Not a full HTML parser — sufficient for Telegram API docs.
public struct HTMLTokenizer: Sendable {
    private enum State {
        case text
        case tagOpen            // after <
        case tagName            // reading tag name
        case closeTagName       // reading /name
        case attrOrEnd          // after tag name, before >
        case attrName           // reading attribute name
        case attrEq             // after attr name, before =
        case attrValueStart     // after =
        case attrValueQuoted(Character)  // inside "..." or '...'
        case attrValueUnquoted  // unquoted attr value
        case comment            // <!-- ... -->
        case doctype            // <!...>
        case selfClose          // /> seen
    }

    public static func tokenize(_ html: String) -> [HTMLToken] {
        var tokens: [HTMLToken] = []
        var state: State = .text
        var buf = ""
        var tagName = ""
        var attrs: [String: String] = [:]
        var currentAttrName = ""
        var currentAttrValue = ""
        var commentBuf = ""
        var isCloseTag = false

        func flushText() {
            if !buf.isEmpty {
                let decoded = decodeEntities(buf)
                if !decoded.isEmpty { tokens.append(.text(decoded)) }
                buf = ""
            }
        }

        func emitTag() {
            let name = tagName.lowercased()
            if isCloseTag {
                tokens.append(.closeTag(name: name))
            } else {
                let selfClose = ["area","base","br","col","embed","hr","img","input",
                                 "link","meta","param","source","track","wbr"].contains(name)
                if selfClose {
                    tokens.append(.selfClosingTag(name: name, attributes: attrs))
                } else {
                    tokens.append(.openTag(name: name, attributes: attrs))
                }
            }
            tagName = ""; attrs = [:]; currentAttrName = ""; currentAttrValue = ""; isCloseTag = false
        }

        let scalars = Array(html.unicodeScalars)
        var i = scalars.startIndex

        while i < scalars.endIndex {
            let ch = Character(scalars[i])
            scalars.formIndex(after: &i)

            switch state {
            case .text:
                if ch == "<" {
                    flushText()
                    state = .tagOpen
                } else {
                    buf.append(ch)
                }

            case .tagOpen:
                if ch == "/" {
                    isCloseTag = true
                    state = .tagName
                } else if ch == "!" {
                    // Could be comment <!-- or DOCTYPE
                    // peek ahead
                    let remaining = String(scalars[i...].prefix(2).map(Character.init))
                    if remaining.hasPrefix("--") {
                        scalars.formIndex(&i, offsetBy: 2)
                        state = .comment
                        commentBuf = ""
                    } else {
                        state = .doctype
                    }
                } else if ch == "?" {
                    state = .doctype
                } else if ch.isLetter || ch == "_" {
                    tagName = String(ch)
                    state = .tagName
                } else {
                    // malformed, treat as text
                    buf.append("<")
                    buf.append(ch)
                    state = .text
                }

            case .tagName:
                if ch.isLetter || ch.isNumber || ch == "-" || ch == "_" || ch == ":" {
                    tagName.append(ch)
                } else if ch.isWhitespace {
                    state = .attrOrEnd
                } else if ch == ">" {
                    emitTag()
                    state = .text
                } else if ch == "/" {
                    state = .selfClose
                } else {
                    tagName.append(ch)
                }

            case .closeTagName:
                if ch == ">" {
                    tokens.append(.closeTag(name: tagName.lowercased()))
                    tagName = ""; isCloseTag = false
                    state = .text
                } else {
                    tagName.append(ch)
                }

            case .attrOrEnd:
                if ch == ">" {
                    emitTag()
                    state = .text
                } else if ch == "/" {
                    state = .selfClose
                } else if ch.isWhitespace {
                    // stay
                } else {
                    currentAttrName = String(ch)
                    state = .attrName
                }

            case .attrName:
                if ch == "=" {
                    state = .attrValueStart
                } else if ch == ">" {
                    attrs[currentAttrName.lowercased()] = ""
                    currentAttrName = ""
                    emitTag()
                    state = .text
                } else if ch.isWhitespace {
                    attrs[currentAttrName.lowercased()] = ""
                    currentAttrName = ""
                    state = .attrEq
                } else {
                    currentAttrName.append(ch)
                }

            case .attrEq:
                if ch == "=" {
                    state = .attrValueStart
                } else if ch == ">" {
                    emitTag()
                    state = .text
                } else if !ch.isWhitespace {
                    currentAttrName = String(ch)
                    state = .attrName
                }

            case .attrValueStart:
                if ch == "\"" || ch == "'" {
                    currentAttrValue = ""
                    state = .attrValueQuoted(ch)
                } else if ch.isWhitespace {
                    // stay
                } else {
                    currentAttrValue = String(ch)
                    state = .attrValueUnquoted
                }

            case .attrValueQuoted(let quote):
                if ch == quote {
                    attrs[currentAttrName.lowercased()] = decodeEntities(currentAttrValue)
                    currentAttrName = ""; currentAttrValue = ""
                    state = .attrOrEnd
                } else {
                    currentAttrValue.append(ch)
                }

            case .attrValueUnquoted:
                if ch.isWhitespace {
                    attrs[currentAttrName.lowercased()] = decodeEntities(currentAttrValue)
                    currentAttrName = ""; currentAttrValue = ""
                    state = .attrOrEnd
                } else if ch == ">" {
                    attrs[currentAttrName.lowercased()] = decodeEntities(currentAttrValue)
                    currentAttrName = ""; currentAttrValue = ""
                    emitTag()
                    state = .text
                } else {
                    currentAttrValue.append(ch)
                }

            case .selfClose:
                if ch == ">" {
                    let name = tagName.lowercased()
                    tokens.append(.selfClosingTag(name: name, attributes: attrs))
                    tagName = ""; attrs = [:]; currentAttrName = ""; currentAttrValue = ""; isCloseTag = false
                    state = .text
                } else {
                    // treat as end of tag name
                    state = .attrOrEnd
                }

            case .comment:
                commentBuf.append(ch)
                if commentBuf.hasSuffix("-->") {
                    commentBuf = ""
                    state = .text
                }

            case .doctype:
                if ch == ">" { state = .text }
            }
        }
        flushText()
        return tokens
    }

    // MARK: – Entity decoding

    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var result = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "&" {
                if let semi = s[i...].firstIndex(of: ";") {
                    let entity = String(s[s.index(after: i)..<semi])
                    let decoded = decodeEntity(entity)
                    result += decoded
                    i = s.index(after: semi)
                    continue
                }
            }
            result.append(s[i])
            i = s.index(after: i)
        }
        return result
    }

    private static func decodeEntity(_ entity: String) -> String {
        if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
            let hex = String(entity.dropFirst(2))
            if let code = UInt32(hex, radix: 16), let scalar = Unicode.Scalar(code) {
                return String(scalar)
            }
        } else if entity.hasPrefix("#") {
            let dec = String(entity.dropFirst())
            if let code = UInt32(dec), let scalar = Unicode.Scalar(code) {
                return String(scalar)
            }
        } else {
            switch entity {
            case "amp":  return "&"
            case "lt":   return "<"
            case "gt":   return ">"
            case "quot": return "\""
            case "apos": return "'"
            case "nbsp": return "\u{00A0}"
            case "mdash": return "\u{2014}"
            case "ndash": return "\u{2013}"
            case "laquo": return "\u{00AB}"
            case "raquo": return "\u{00BB}"
            default: break
            }
        }
        return "&\(entity);"
    }
}
