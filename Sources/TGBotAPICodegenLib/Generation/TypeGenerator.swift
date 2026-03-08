import Foundation

// Swift keywords that need backtick escaping when used as identifiers
private let swiftKeywords: Set<String> = [
    "default", "static", "class", "struct", "enum", "func", "var", "let", "case",
    "switch", "if", "else", "for", "while", "return", "import", "init", "self",
    "super", "true", "false", "nil", "in", "is", "as", "do", "try", "catch",
    "throw", "throws", "guard", "break", "continue", "where", "public", "private",
    "internal", "open", "fileprivate", "protocol", "extension", "some", "any",
    "actor", "async", "await", "operator", "associatedtype", "typealias",
    "subscript", "deinit", "indirect", "mutating", "final", "override",
    "required", "convenience", "weak", "unowned", "lazy", "rethrows",
    "infix", "prefix", "postfix", "get", "set", "willSet", "didSet",
]

private func escapeIdentifier(_ name: String) -> String {
    swiftKeywords.contains(name) ? "`\(name)`" : name
}

public enum TypeGenerator {

    /// Generate all type declarations: TGBox, TGInputFile, union enums, concrete structs/enums.
    public static func generate(
        types: [String: APIType],
        unionEnums: [String: String],   // key → Swift enum name
        boxedFields: [String: Set<String>] = [:]  // typeName → set of field names to wrap in TGBox
    ) -> String {
        var lines: [String] = [
            "import Foundation",
            "",
            "// MARK: - Box wrapper (breaks recursive value-type cycles)",
            "",
            "/// A heap-allocated wrapper used to break struct recursion cycles.",
            "/// Access the wrapped value via `.value`.",
            "public final class TGBox<T: Codable & Sendable>: Codable, @unchecked Sendable {",
            "    public let value: T",
            "    public init(_ value: T) { self.value = value }",
            "    public init(from decoder: Decoder) throws { value = try T(from: decoder) }",
            "    public func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }",
            "}",
            "",
            "// MARK: - Input file",
            "",
            "/// Represents a file to upload.",
            "public struct TGInputFile: Codable, Sendable {",
            "    public let data: Data",
            "    public let filename: String",
            "    public let mimeType: String",
            "    public init(data: Data, filename: String, mimeType: String) {",
            "        self.data = data; self.filename = filename; self.mimeType = mimeType",
            "    }",
            "}",
            "",
        ]

        // Union type enums (deduplicated)
        if !unionEnums.isEmpty {
            lines += ["// MARK: - Union type enums", ""]
            var seen = Set<String>()
            var enumDefs: [(name: String, types: [String])] = []
            for (key, name) in unionEnums.sorted(by: { $0.value < $1.value }) {
                if !seen.contains(name) {
                    seen.insert(name)
                    enumDefs.append((name: name, types: key.components(separatedBy: "|")))
                }
            }
            for def in enumDefs.sorted(by: { $0.name < $1.name }) {
                lines += generateUnionEnum(name: def.name, tgTypes: def.types, unionEnums: unionEnums)
                lines.append("")
            }
        }

        // Concrete types
        lines += ["// MARK: - Types", ""]

        // Sort types: abstract enums first, then concrete structs; alphabetical within each group
        let sortedTypes = types.values.sorted { a, b in
            let aIsEnum = !(a.subtypes ?? []).isEmpty
            let bIsEnum = !(b.subtypes ?? []).isEmpty
            if aIsEnum != bIsEnum { return aIsEnum }
            return a.name < b.name
        }

        for t in sortedTypes where t.name != "InputFile" {
            if !(t.subtypes ?? []).isEmpty {
                lines += generateAbstractEnum(type: t, types: types, unionEnums: unionEnums)
            } else {
                lines += generateStruct(type: t, unionEnums: unionEnums, boxedFieldNames: boxedFields[t.name] ?? [])
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: – Union enum

    static func generateUnionEnum(name: String, tgTypes: [String], unionEnums: [String: String]) -> [String] {
        var lines: [String] = []
        lines.append("public enum \(name): Codable, Sendable {")
        for tg in tgTypes {
            let swift = TypeMapper.swiftType(for: tg)
            let caseName = escapeIdentifier(unionCaseName(for: tg))
            lines.append("    case \(caseName)(\(swift))")
        }
        lines.append("")
        lines.append("    public init(from decoder: Decoder) throws {")
        lines.append("        let c = try decoder.singleValueContainer()")
        for (idx, tg) in tgTypes.enumerated() {
            let swift = TypeMapper.swiftType(for: tg)
            let caseName = escapeIdentifier(unionCaseName(for: tg))
            if idx < tgTypes.count - 1 {
                lines.append("        if let v = try? c.decode(\(swift).self) { self = .\(caseName)(v); return }")
            } else {
                lines.append("        self = .\(caseName)(try c.decode(\(swift).self))")
            }
        }
        lines.append("    }")
        lines.append("")
        lines.append("    public func encode(to encoder: Encoder) throws {")
        lines.append("        var c = encoder.singleValueContainer()")
        lines.append("        switch self {")
        for tg in tgTypes {
            let caseName = escapeIdentifier(unionCaseName(for: tg))
            lines.append("        case .\(caseName)(let v): try c.encode(v)")
        }
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        return lines
    }

    private static func unionCaseName(for tgType: String) -> String {
        if tgType.hasPrefix("Array of ") {
            let inner = String(tgType.dropFirst("Array of ".count))
            return "arrayOf\(inner)"
        }
        let swift = TypeMapper.swiftType(for: tgType)
        let stripped = swift.hasPrefix("TG") ? String(swift.dropFirst(2)) : swift
        return stripped.prefix(1).lowercased() + stripped.dropFirst()
    }

    // MARK: – Abstract enum (type with subtypes)

    /// Finds the discriminator field for an abstract type's subtypes.
    /// Returns `(fieldName, [(subtypeName, discriminatorValue)])` if a
    /// string discriminator exists (`type`, `source`, `status`, etc.),
    /// or `nil` when try-each decoding is needed.
    private static func findDiscriminator(
        subtypes: [String],
        types: [String: APIType]
    ) -> (field: String, values: [(subtype: String, value: String)])? {
        // Candidate field names used as discriminators in the Telegram API
        let candidates = ["type", "source", "status"]
        for candidate in candidates {
            var values: [(String, String)] = []
            var allHaveIt = true
            for sub in subtypes {
                guard let info = types[sub],
                      let fields = info.fields,
                      let field = fields.first(where: { $0.name == candidate }) else {
                    allHaveIt = false
                    break
                }
                let desc = field.description
                if let range = desc.range(of: #"always "([^"]+)""#, options: .regularExpression) {
                    let matched = String(desc[range])
                    let parts = matched.components(separatedBy: "\"")
                    if parts.count >= 2 {
                        values.append((sub, parts[1]))
                        continue
                    }
                }
                allHaveIt = false
                break
            }
            if allHaveIt && values.count == subtypes.count {
                return (candidate, values)
            }
        }
        return nil
    }

    static func generateAbstractEnum(type t: APIType, types: [String: APIType], unionEnums: [String: String]) -> [String] {
        var lines: [String] = []

        if !t.description.isEmpty {
            lines.append(t.description.joined(separator: " ").asDocComment(indent: ""))
        }

        // Mark as indirect to break potential recursion (enum ↔ struct cycles)
        lines.append("public indirect enum TG\(t.name): Codable, Sendable {")

        let subtypes = t.subtypes ?? []
        for sub in subtypes {
            let caseName = escapeIdentifier(deriveEnumCaseName(subtype: sub, parent: t.name))
            lines.append("    case \(caseName)(TG\(sub))")
        }
        lines.append("")

        let disc = findDiscriminator(subtypes: subtypes, types: types)

        // init(from:)
        if let disc {
            // Keyed discriminator strategy
            let snakeField = disc.field
            let camelField = snakeField.snakeToCamelCase
            lines.append("    private enum CK: String, CodingKey { case \(camelField) = \"\(snakeField)\" }")
            lines.append("")
            lines.append("    public init(from decoder: Decoder) throws {")
            lines.append("        let c = try decoder.container(keyedBy: CK.self)")
            lines.append("        let disc = try c.decode(String.self, forKey: .\(camelField))")
            lines.append("        switch disc {")
            for (sub, value) in disc.values {
                let caseName = escapeIdentifier(deriveEnumCaseName(subtype: sub, parent: t.name))
                lines.append("        case \"\(value)\":")
                lines.append("            self = .\(caseName)(try TG\(sub)(from: decoder))")
            }
            lines.append("        default:")
            lines.append("            throw DecodingError.dataCorrupted(DecodingError.Context(")
            lines.append("                codingPath: decoder.codingPath,")
            lines.append("                debugDescription: \"Unknown \(t.name) discriminator: \\(disc)\"))")
            lines.append("        }")
            lines.append("    }")
        } else {
            // Try-each strategy: attempt to decode each subtype in order
            lines.append("    public init(from decoder: Decoder) throws {")
            for (idx, sub) in subtypes.enumerated() {
                let caseName = escapeIdentifier(deriveEnumCaseName(subtype: sub, parent: t.name))
                if idx < subtypes.count - 1 {
                    lines.append("        if let v = try? TG\(sub)(from: decoder) { self = .\(caseName)(v); return }")
                } else {
                    lines.append("        self = .\(caseName)(try TG\(sub)(from: decoder))")
                }
            }
            lines.append("    }")
        }

        lines.append("")
        lines.append("    public func encode(to encoder: Encoder) throws {")
        lines.append("        switch self {")
        for sub in subtypes {
            let caseName = escapeIdentifier(deriveEnumCaseName(subtype: sub, parent: t.name))
            lines.append("        case .\(caseName)(let v): try v.encode(to: encoder)")
        }
        lines.append("        }")
        lines.append("    }")
        lines.append("}")
        return lines
    }

    private static func deriveEnumCaseName(subtype: String, parent: String) -> String {
        var name = subtype
        if name.hasPrefix(parent) { name = String(name.dropFirst(parent.count)) }
        if name.isEmpty { name = subtype }
        return name.prefix(1).lowercased() + name.dropFirst()
    }

    private static func camelToSnake(_ s: String) -> String {
        var result = ""
        for (i, ch) in s.enumerated() {
            if ch.isUppercase && i > 0 { result.append("_") }
            result.append(contentsOf: ch.lowercased())
        }
        return result
    }

    /// Types emitted as `final class` instead of `struct` to keep their
    /// inline size small (8-byte reference).  `TGMessage` (~100 fields)
    /// appears 6 times inside `TGUpdate`; without this, `TGUpdate` exceeds
    /// the 64 KB async-task stack limit and causes SIGBUS at runtime.
    static let classTypes: Set<String> = ["Message"]

    // MARK: – Concrete struct / class

    static func generateStruct(
        type t: APIType,
        unionEnums: [String: String],
        boxedFieldNames: Set<String> = []
    ) -> [String] {
        var lines: [String] = []

        if !t.description.isEmpty {
            lines.append(t.description.joined(separator: " ").asDocComment(indent: ""))
        }

        let fields = t.fields ?? []
        let isClass = classTypes.contains(t.name)
        if isClass {
            lines.append("public final class TG\(t.name): Codable, Sendable {")
        } else {
            lines.append("public struct TG\(t.name): Codable, Sendable {")
        }

        // Properties
        for field in fields {
            let swiftName = field.name.snakeToCamelCase
            let isBoxed = boxedFieldNames.contains(field.name)
            if isBoxed {
                let innerSwiftType = innerType(forTypes: field.types, unionEnums: unionEnums)
                // Required boxed: TGBox<T>  |  Optional boxed: TGBox<T>?
                let optional = field.required ? "" : "?"
                lines.append("    public let \(swiftName): TGBox<\(innerSwiftType)>\(optional)")
            } else {
                let swiftType = TypeMapper.swiftType(forTypes: field.types, unionEnums: unionEnums)
                let optional = field.required ? "" : "?"
                lines.append("    public let \(swiftName): \(swiftType)\(optional)")
            }
        }

        // CodingKeys (if any name needs mapping)
        let needsCodingKeys = fields.contains { $0.name != $0.name.snakeToCamelCase }
        if needsCodingKeys && !fields.isEmpty {
            lines.append("")
            lines.append("    private enum CodingKeys: String, CodingKey {")
            for field in fields {
                let swiftName = field.name.snakeToCamelCase
                if swiftName == field.name {
                    lines.append("        case \(swiftName)")
                } else {
                    lines.append("        case \(swiftName) = \"\(field.name)\"")
                }
            }
            lines.append("    }")
        }

        // Public init
        if !fields.isEmpty {
            lines.append("")
            let params = fields.map { field -> String in
                let swiftName = field.name.snakeToCamelCase
                let isBoxed = boxedFieldNames.contains(field.name)
                let innerT = innerType(forTypes: field.types, unionEnums: unionEnums)
                if isBoxed {
                    let optional = field.required ? "" : "?"
                    let defaultVal = field.required ? "" : " = nil"
                    return "\(swiftName): \(innerT)\(optional)\(defaultVal)"
                } else {
                    let swiftType = TypeMapper.swiftType(forTypes: field.types, unionEnums: unionEnums)
                    let optional = field.required ? "" : "?"
                    let defaultVal = field.required ? "" : " = nil"
                    return "\(swiftName): \(swiftType)\(optional)\(defaultVal)"
                }
            }.joined(separator: ", ")
            lines.append("    public init(\(params)) {")
            for field in fields {
                let swiftName = field.name.snakeToCamelCase
                let isBoxed = boxedFieldNames.contains(field.name)
                if isBoxed {
                    if field.required {
                        lines.append("        self.\(swiftName) = TGBox(\(swiftName))")
                    } else {
                        lines.append("        self.\(swiftName) = \(swiftName).map { TGBox($0) }")
                    }
                } else {
                    lines.append("        self.\(swiftName) = \(swiftName)")
                }
            }
            lines.append("    }")
        } else {
            lines.append("    public init() {}")
        }

        lines.append("}")
        return lines
    }

    /// Returns the Swift type for use inside a TGBox (first type, non-array-stripped).
    private static func innerType(forTypes types: [String], unionEnums: [String: String]) -> String {
        if types.count == 1 {
            let t = types[0]
            if t.hasPrefix("Array of ") {
                return TypeMapper.swiftType(for: t)
            }
            return TypeMapper.swiftType(for: t)
        }
        return TypeMapper.swiftType(forTypes: types, unionEnums: unionEnums)
    }
}
