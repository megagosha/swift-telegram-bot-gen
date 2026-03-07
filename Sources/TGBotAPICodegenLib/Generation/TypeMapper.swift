import Foundation

/// Maps Telegram API type strings to Swift type strings.
public enum TypeMapper {
    /// The set of Telegram primitive types (not prefixed with TG).
    static let primitives: Set<String> = ["String", "Integer", "Boolean", "Float", "InputFile"]

    /// Maps a single TG type string (from api.json `types` array entry) to a Swift type string.
    /// `unionEnums` maps sorted-type-key → Swift enum name for multi-type fields.
    public static func swiftType(for tgType: String, unionEnums: [String: String] = [:]) -> String {
        if tgType.hasPrefix("Array of ") {
            let inner = String(tgType.dropFirst("Array of ".count))
            return "[\(swiftType(for: inner, unionEnums: unionEnums))]"
        }
        switch tgType {
        case "String":   return "String"
        case "Integer":  return "Int"
        case "Boolean":  return "Bool"
        case "Float":    return "Double"
        case "InputFile": return "TGInputFile"
        default:         return "TG\(tgType)"
        }
    }

    /// Given an array of TG types from a field, returns the Swift type string.
    /// If `types` has more than one entry the union enum name is looked up.
    public static func swiftType(forTypes types: [String], unionEnums: [String: String]) -> String {
        if types.count == 1 {
            return swiftType(for: types[0], unionEnums: unionEnums)
        }
        let key = unionKey(for: types)
        if let name = unionEnums[key] { return name }
        // Fallback: first type
        return swiftType(for: types[0], unionEnums: unionEnums)
    }

    /// The key used to deduplicate union type combinations. Sorted join of TG type names.
    public static func unionKey(for types: [String]) -> String {
        types.sorted().joined(separator: "|")
    }

    /// Generate a Swift enum name for a union of types, e.g. ["Integer","String"] → "TGIntOrString".
    public static func unionEnumName(for types: [String]) -> String {
        // Sort by "core types first, then alphabetical"
        let sorted = types.sorted { a, b in
            let aCore = primitives.contains(a)
            let bCore = primitives.contains(b)
            if aCore != bCore { return aCore }
            return a < b
        }
        let parts = sorted.map { t -> String in
            let base: String
            if t.hasPrefix("Array of ") {
                let inner = String(t.dropFirst("Array of ".count))
                base = "ArrayOf\(inner)"
            } else {
                base = t
            }
            return swiftType(for: base).replacingOccurrences(of: "TG", with: "")
        }
        return "TG\(parts.joined(separator: "Or"))"
    }
}
