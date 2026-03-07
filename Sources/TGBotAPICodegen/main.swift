import Foundation
import TGBotAPICodegenLib

// Usage:
//   TGBotAPICodegen fetch   <output-api-json-path>
//   TGBotAPICodegen generate <input-api-json-path> <output-dir>

let args = CommandLine.arguments

guard args.count >= 2 else {
    fputs("Usage: TGBotAPICodegen <fetch|generate> [args...]\n", stderr)
    exit(1)
}

let mode = args[1]

switch mode {
case "fetch":
    guard args.count >= 3 else {
        fputs("Usage: TGBotAPICodegen fetch <output-api-json-path>\n", stderr)
        exit(1)
    }
    let outputPath = args[2]
    do {
        print("Fetching Telegram Bot API docs...")
        let html = try Fetcher.fetchHTML(from: "https://core.telegram.org/bots/api")
        print("Parsing...")
        var spec = try APIParser.parse(html: html)
        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(spec)
        let url = URL(fileURLWithPath: outputPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url)
        print("Wrote \(outputPath)")
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }

case "generate":
    guard args.count >= 4 else {
        fputs("Usage: TGBotAPICodegen generate <input-api-json-path> <output-dir>\n", stderr)
        exit(1)
    }
    let inputPath = args[2]
    let outputDirPath = args[3]
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: inputPath))
        let outputDir = URL(fileURLWithPath: outputDirPath)
        try CodeGenerator.generate(from: data, outputDir: outputDir)
        print("Generated Swift files in \(outputDirPath)")
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }

default:
    fputs("Unknown mode '\(mode)'. Expected 'fetch' or 'generate'.\n", stderr)
    exit(1)
}
