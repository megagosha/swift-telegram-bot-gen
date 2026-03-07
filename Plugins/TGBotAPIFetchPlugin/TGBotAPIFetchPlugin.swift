import PackagePlugin
import Foundation

@main struct TGBotAPIFetchPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let outputJSON = context.package.directoryURL.appending(path: "Resources/api.json")
        let tool = try context.tool(named: "TGBotAPICodegen")
        let process = Process()
        process.executableURL = tool.url
        process.arguments = ["fetch", outputJSON.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw PluginError.fetchFailed }
        print("Updated \(outputJSON.path)")
    }

    enum PluginError: Error { case fetchFailed }
}
