import PackagePlugin

@main struct TGBotAPIBuildPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) throws -> [Command] {
        let apiJSON = context.package.directoryURL.appending(path: "Resources/api.json")
        let outDir = context.pluginWorkDirectoryURL.appending(path: "Generated")
        let outputs = ["TGBotAPIVersion.swift", "TGBotAPITypes.swift", "TGBotAPIMethods.swift"]
            .map { outDir.appending(path: $0) }
        return [
            .buildCommand(
                displayName: "Generate Telegram Bot API Swift types",
                executable: try context.tool(named: "TGBotAPICodegen").url,
                arguments: ["generate", apiJSON.path, outDir.path],
                inputFiles: [apiJSON],
                outputFiles: outputs
            )
        ]
    }
}
