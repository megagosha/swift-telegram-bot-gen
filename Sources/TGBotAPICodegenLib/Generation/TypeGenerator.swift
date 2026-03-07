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
        lines.append("    private enum CK: String, CodingKey { case type }")
        lines.append("")
        lines.append("    public init(from decoder: Decoder) throws {")
        lines.append("        let c = try decoder.container(keyedBy: CK.self)")
        lines.append("        let type_ = try c.decode(String.self, forKey: .type)")
        lines.append("        switch type_ {")
        for sub in subtypes {
            let discriminator = extractDiscriminator(typeName: sub, types: types)
            let caseName = escapeIdentifier(deriveEnumCaseName(subtype: sub, parent: t.name))
            lines.append("        case \"\(discriminator)\":")
            lines.append("            self = .\(caseName)(try TG\(sub)(from: decoder))")
        }
        lines.append("        default:")
        lines.append("            throw DecodingError.dataCorruptedError(forKey: .type, in: c,")
        lines.append("                debugDescription: \"Unknown \(t.name) type: \\(type_)\")")
        lines.append("        }")
        lines.append("    }")
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

    private static func extractDiscriminator(typeName: String, types: [String: APIType]) -> String {
        guard let typeInfo = types[typeName],
              let fields = typeInfo.fields,
              let typeField = fields.first(where: { $0.name == "type" }) else {
            return camelToSnake(typeName)
        }
        let desc = typeField.description
        // Look for: always "X"
        if let range = desc.range(of: #"always "([^"]+)""#, options: .regularExpression) {
            let matched = String(desc[range])
            let parts = matched.components(separatedBy: "\"")
            if parts.count >= 2 { return parts[1] }
        }
        return camelToSnake(typeName)
    }

    private static func camelToSnake(_ s: String) -> String {
        var result = ""
        for (i, ch) in s.enumerated() {
            if ch.isUppercase && i > 0 { result.append("_") }
            result.append(contentsOf: ch.lowercased())
        }
        return result
    }

    // MARK: – Concrete struct

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
        lines.append("public struct TG\(t.name): Codable, Sendable {")

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
