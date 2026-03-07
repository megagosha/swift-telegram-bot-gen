import Foundation

public extension String {
    /// Converts snake_case to camelCase. E.g. "chat_id" → "chatId".
    var snakeToCamelCase: String {
        let parts = self.components(separatedBy: "_")
        guard parts.count > 1 else { return self }
        let first = parts[0]
        let rest = parts[1...].map { part -> String in
            guard let firstChar = part.first else { return part }
            return firstChar.uppercased() + part.dropFirst()
        }
        return first + rest.joined()
    }

    /// Capitalises the first character, leaving the rest unchanged.
    var capitalizedFirst: String {
        guard let first = self.first else { return self }
        return first.uppercased() + self.dropFirst()
    }

    /// Formats a description string as Swift doc-comment lines (/// prefix).
    func asDocComment(indent: String = "    ") -> String {
        let lines = self.components(separatedBy: "\n")
        return lines.map { "\(indent)/// \($0)" }.joined(separator: "\n")
    }
}
