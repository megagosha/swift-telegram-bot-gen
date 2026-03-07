import Foundation

public enum CodeGenerator {

    public static func generate(from jsonData: Data, outputDir: URL) throws {
        let decoder = JSONDecoder()
        let spec = try decoder.decode(APISpec.self, from: jsonData)

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

        // Collect all union type combos from all fields (types + methods)
        var unionEnums: [String: String] = [:]
        for t in spec.types.values {
            for f in (t.fields ?? []) where f.types.count > 1 {
                let key = TypeMapper.unionKey(for: f.types)
                if unionEnums[key] == nil { unionEnums[key] = TypeMapper.unionEnumName(for: f.types) }
            }
        }
        for m in spec.methods.values {
            for f in (m.fields ?? []) where f.types.count > 1 {
                let key = TypeMapper.unionKey(for: f.types)
                if unionEnums[key] == nil { unionEnums[key] = TypeMapper.unionEnumName(for: f.types) }
            }
        }

        // Detect fields that need TGBox<T> wrapping to break struct size cycles
        let boxedFields = computeBoxedFields(types: spec.types)

        // 1. TGBotAPIVersion.swift
        let versionCode = generateVersion(spec: spec)
        try write(versionCode, to: outputDir.appendingPathComponent("TGBotAPIVersion.swift"))

        // 2. TGBotAPITypes.swift
        let typesCode = TypeGenerator.generate(types: spec.types, unionEnums: unionEnums, boxedFields: boxedFields)
        try write(typesCode, to: outputDir.appendingPathComponent("TGBotAPITypes.swift"))

        // 3. TGBotAPIMethods.swift
        let methodsCode = MethodGenerator.generate(methods: spec.methods, unionEnums: unionEnums)
        try write(methodsCode, to: outputDir.appendingPathComponent("TGBotAPIMethods.swift"))
    }

    // MARK: – Cycle detection

    /// Returns a map from type name → set of field names that need TGBox<T> wrapping.
    ///
    /// Uses DFS back-edge detection: a field is boxed only when it's a direct (non-array) reference
    /// that closes a cycle (back-edge in the DFS tree). Non-cyclic types are never boxed.
    static func computeBoxedFields(types: [String: APIType]) -> [String: Set<String>] {
        // Only concrete structs (abstract enums use `indirect enum` instead)
        let structTypes = Set(types.filter { $0.value.subtypes == nil }.keys)

        // Build adjacency: typeName → [(fieldName, depTypeName)]
        // Only direct (non-array) edges to other struct types
        var adj: [String: [(field: String, dep: String)]] = [:]
        for name in structTypes {
            var edges: [(String, String)] = []
            for f in (types[name]?.fields ?? []) {
                for tgType in f.types {
                    if !tgType.hasPrefix("Array of ") && structTypes.contains(tgType) {
                        edges.append((f.name, tgType))
                        break
                    }
                }
            }
            adj[name] = edges
        }

        var boxedFields: [String: Set<String>] = [:]
        var visited = Set<String>()
        var inStack = Set<String>()  // nodes on the current DFS path

        // DFS with back-edge detection. When a back-edge (→ ancestor in stack) is found,
        // box that field to break the cycle. Then skip that edge.
        func dfs(_ node: String) {
            visited.insert(node)
            inStack.insert(node)

            var remaining: [(field: String, dep: String)] = []
            for edge in (adj[node] ?? []) {
                if inStack.contains(edge.dep) {
                    // Back edge → this field creates a cycle; box it
                    boxedFields[node, default: []].insert(edge.field)
                    // Do NOT recurse — this edge is removed from the graph
                } else {
                    remaining.append(edge)
                    if !visited.contains(edge.dep) {
                        dfs(edge.dep)
                    }
                }
            }
            adj[node] = remaining
            inStack.remove(node)
        }

        for typeName in structTypes.sorted() {  // sorted for determinism
            if !visited.contains(typeName) { dfs(typeName) }
        }

        return boxedFields
    }

    // MARK: – Version file

    private static func generateVersion(spec: APISpec) -> String {
        return """
        // Auto-generated — do not edit manually.
        public enum TGBotAPIVersion {
            public static let version = "\(spec.version)"
            public static let releaseDate = "\(spec.releaseDate)"
            public static let changelog = "\(spec.changelog)"
        }
        """
    }

    private static func write(_ content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
