// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "swift-telegram-bot-gen",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "TGBotAPI", targets: ["TGBotAPI"]),
        .library(name: "TGBot", targets: ["TGBot"]),
    ],
    targets: [
        .target(
            name: "TGBotAPICodegenLib",
            path: "Sources/TGBotAPICodegenLib",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .executableTarget(
            name: "TGBotAPICodegen",
            dependencies: [.target(name: "TGBotAPICodegenLib")],
            path: "Sources/TGBotAPICodegen",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .target(
            name: "TGBotAPI",
            path: "Sources/TGBotAPI",
            swiftSettings: [.swiftLanguageMode(.v6)],
            plugins: [.plugin(name: "TGBotAPIBuildPlugin")]
        ),
        .plugin(
            name: "TGBotAPIBuildPlugin",
            capability: .buildTool(),
            dependencies: [.target(name: "TGBotAPICodegen")]
        ),
        .plugin(
            name: "TGBotAPIFetchPlugin",
            capability: .command(
                intent: .custom(
                    verb: "fetch-tg-api",
                    description: "Download and parse the Telegram Bot API docs, updating Resources/api.json"
                ),
                permissions: [
                    .allowNetworkConnections(
                        scope: .all(ports: [443, 80]),
                        reason: "Download Telegram Bot API documentation from core.telegram.org"
                    ),
                    .writeToPackageDirectory(reason: "Write updated api.json to Resources/")
                ]
            ),
            dependencies: [.target(name: "TGBotAPICodegen")]
        ),
        .target(
            name: "TGBot",
            dependencies: [.target(name: "TGBotAPI")],
            path: "Sources/TGBot",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TGBotAPICodegenTests",
            dependencies: [.target(name: "TGBotAPICodegenLib")],
            path: "Tests/TGBotAPICodegenTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
        .testTarget(
            name: "TGBotTests",
            dependencies: [.target(name: "TGBot")],
            path: "Tests/TGBotTests",
            swiftSettings: [.swiftLanguageMode(.v6)]
        ),
    ]
)
