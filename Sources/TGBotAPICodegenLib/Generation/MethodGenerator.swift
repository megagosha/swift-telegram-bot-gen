import Foundation

public enum MethodGenerator {

    public static func generate(methods: [String: APIMethod], unionEnums: [String: String]) -> String {
        var lines: [String] = [
            "import Foundation",
            "",
            "// MARK: - Method parameter structs",
            "",
        ]

        for method in methods.values.sorted(by: { $0.name < $1.name }) {
            lines += generateMethodParams(method: method, unionEnums: unionEnums)
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    static func generateMethodParams(method: APIMethod, unionEnums: [String: String]) -> [String] {
        var lines: [String] = []

        let structName = "TG\(method.name.prefix(1).uppercased() + method.name.dropFirst())Params"

        if !method.description.isEmpty {
            lines.append(method.description.joined(separator: " ").asDocComment(indent: ""))
        }

        let fields = method.fields ?? []
        lines.append("public struct \(structName): Codable, Sendable {")

        // Properties
        for field in fields {
            let swiftName = field.name.snakeToCamelCase
            let swiftType = TypeMapper.swiftType(forTypes: field.types, unionEnums: unionEnums)
            let optional = field.required ? "" : "?"
            lines.append("    public let \(swiftName): \(swiftType)\(optional)")
        }

        // CodingKeys
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
                let swiftType = TypeMapper.swiftType(forTypes: field.types, unionEnums: unionEnums)
                let optional = field.required ? "" : "?"
                let defaultVal = field.required ? "" : " = nil"
                return "\(swiftName): \(swiftType)\(optional)\(defaultVal)"
            }.joined(separator: ", ")
            lines.append("    public init(\(params)) {")
            for field in fields {
                let swiftName = field.name.snakeToCamelCase
                lines.append("        self.\(swiftName) = \(swiftName)")
            }
            lines.append("    }")
        } else {
            lines.append("    public init() {}")
        }

        lines.append("}")
        return lines
    }
}
