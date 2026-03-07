# swift-telegram-bot-gen

Auto-generated Swift types and a long-polling bot framework for the [Telegram Bot API](https://core.telegram.org/bots/api).

- **289 Codable + Sendable types** and **166 method-param structs** generated directly from the official Telegram docs
- **Zero external dependencies** — Foundation + os only
- **Swift 6 strict concurrency** — actors, Sendable, async/await throughout
- Types are regenerated at build time via an SPM build-tool plugin, so they stay in sync with the spec automatically

Currently tracking **Bot API 9.5** (March 1, 2026).

## Products

| Product | Description |
|---------|-------------|
| `TGBotAPI` | Generated Telegram Bot API types and method-param structs |
| `TGBot` | Long-polling bot framework with handler/dispatcher architecture |

## Installation

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/aspect-build/swift-telegram-bot-gen", from: "1.0.0"),
    // or use a local path:
    // .package(path: "../swift-telegram-bot-gen"),
]
```

Then add the product(s) you need to your target:

```swift
.target(
    name: "MyBot",
    dependencies: [
        .product(name: "TGBot", package: "swift-telegram-bot-gen"),
        // TGBotAPI is included transitively via TGBot.
        // Import it directly if you only need the types:
        // .product(name: "TGBotAPI", package: "swift-telegram-bot-gen"),
    ]
)
```

## Quick Start

```swift
import TGBot
import TGBotAPI

@main
struct MyBot {
    static func main() async {
        let bot = TGBot(
            token: ProcessInfo.processInfo.environment["BOT_TOKEN"]!,
            handlers: [
                TGCommandHandler(command: "/start") { msg, client in
                    let _: Bool = try await client.post("sendMessage", params: TGSendMessageParams(
                        chatId: .int(msg.chat.id),
                        text: "Hello! I'm a bot."
                    ))
                },

                TGCommandHandler(command: "/help") { msg, client in
                    let _: Bool = try await client.post("sendMessage", params: TGSendMessageParams(
                        chatId: .int(msg.chat.id),
                        text: "Available commands: /start, /help"
                    ))
                },

                TGMessageHandler { msg, client in
                    let _: Bool = try await client.post("sendMessage", params: TGSendMessageParams(
                        chatId: .int(msg.chat.id),
                        text: "You said: \(msg.text ?? "(no text)")"
                    ))
                },
            ]
        )

        await bot.run()
    }
}
```

Set your bot token and run:

```bash
export BOT_TOKEN="123456:ABC-DEF..."
swift run MyBot
```

## Handlers

### Built-in handlers

**TGCommandHandler** — matches messages starting with a `/command`. Handles `@BotName` suffixes and arguments automatically.

```swift
TGCommandHandler(command: "/ping") { msg, client in
    let _: Bool = try await client.post("sendMessage", params: TGSendMessageParams(
        chatId: .int(msg.chat.id),
        text: "pong"
    ))
}
```

**TGMessageHandler** — fires on every `update.message`.

```swift
TGMessageHandler { msg, client in
    print("Received: \(msg.text ?? "")")
}
```

**TGCallbackQueryHandler** — fires on inline keyboard callback queries.

```swift
TGCallbackQueryHandler { query, client in
    let _: Bool = try await client.post("answerCallbackQuery", params: TGAnswerCallbackQueryParams(
        callbackQueryId: query.id,
        text: "Button pressed!"
    ))
}
```

### Custom handlers

Conform to `TGHandlerProtocol` to create your own:

```swift
struct PhotoHandler: TGHandlerProtocol {
    func shouldProcess(_ update: TGUpdate) -> Bool {
        update.message?.photo != nil
    }

    func handle(_ update: TGUpdate, client: any TGBotClientProtocol) async throws {
        guard let msg = update.message else { return }
        let _: Bool = try await client.post("sendMessage", params: TGSendMessageParams(
            chatId: .int(msg.chat.id),
            text: "Nice photo!"
        ))
    }
}
```

Handlers are evaluated in order. All matching handlers run for each update — a thrown error in one handler does not prevent subsequent handlers from executing.

## Configuration

```swift
let bot = TGBot(
    token: "...",
    handlers: [...],
    config: TGBotConfiguration(
        minRequestInterval: 0.1,           // throttle between HTTP calls (seconds)
        pollingConfig: TGLongPollingConfig(
            timeout: 60,                   // long-poll server timeout (seconds)
            limit: 50,                     // max updates per poll (nil = server default)
            allowedUpdates: ["message", "callback_query"]  // filter update types
        )
    )
)
```

Default values: `minRequestInterval = 0.05s`, `timeout = 30s`, `limit = nil`, `allowedUpdates = nil`.

## Calling API Methods

The `client` passed to handlers (and available as `bot.client`) can call any Telegram Bot API method. The method name matches the [official API](https://core.telegram.org/bots/api#available-methods), and the params struct is the method name in PascalCase with a `TG` prefix and `Params` suffix:

| API method | Params struct |
|------------|---------------|
| `sendMessage` | `TGSendMessageParams` |
| `sendPhoto` | `TGSendPhotoParams` |
| `answerCallbackQuery` | `TGAnswerCallbackQueryParams` |
| `banChatMember` | `TGBanChatMemberParams` |

```swift
// Send a message
let result: TGMessage = try await client.post("sendMessage", params: TGSendMessageParams(
    chatId: .int(chatId),
    text: "Hello"
))

// Delete a message (returns Bool)
let _: Bool = try await client.post("deleteMessage", params: TGDeleteMessageParams(
    chatId: .int(chatId),
    messageId: messageId
))
```

The return type is inferred from the call site. Check the [Telegram Bot API docs](https://core.telegram.org/bots/api) for what each method returns.

## Using TGBotAPI Standalone

If you only need the generated types (e.g. for a webhook-based bot or a different HTTP stack), depend on `TGBotAPI` alone:

```swift
.product(name: "TGBotAPI", package: "swift-telegram-bot-gen")
```

This gives you all `TG*` types, method-param structs, and `TGBotAPIVersion` with no runtime overhead.

## Updating the API Spec

When Telegram releases a new Bot API version:

```bash
# Re-scrape the official docs and update Resources/api.json
swift package fetch-tg-api

# Rebuild — the build plugin regenerates types automatically
swift build
```

## Architecture

```
swift-telegram-bot-gen/
├── Resources/api.json                  # Telegram Bot API spec (scraped from docs)
├── Sources/
│   ├── TGBotAPICodegenLib/             # HTML parser + Swift code generator
│   ├── TGBotAPICodegen/                # CLI entry point for codegen
│   ├── TGBotAPI/                       # Generated types (via build plugin)
│   │   └── Module.swift                # Stub; real code is generated at build time
│   └── TGBot/                          # Bot framework
│       ├── TGBot.swift                 # Main entry point (actor)
│       ├── TGBotClient.swift           # HTTP client (actor, URLSession)
│       ├── TGBotClientProtocol.swift   # Protocol for mocking
│       ├── TGBotConfiguration.swift    # Config structs
│       ├── TGBotError.swift            # Error types
│       ├── TGContainer.swift           # API response wrapper
│       ├── LongPolling/
│       │   └── TGLongPoller.swift      # getUpdates loop -> AsyncStream
│       └── Handlers/
│           ├── TGHandlerProtocol.swift # Handler protocol
│           ├── TGDispatcher.swift      # Routes updates to handlers
│           ├── TGMessageHandler.swift
│           ├── TGCommandHandler.swift
│           └── TGCallbackQueryHandler.swift
├── Plugins/
│   ├── TGBotAPIBuildPlugin/            # Build plugin: api.json -> Swift files
│   └── TGBotAPIFetchPlugin/           # Command plugin: scrapes docs -> api.json
└── Tests/
    ├── TGBotAPICodegenTests/           # 52 codegen tests
    └── TGBotTests/                     # 23 bot framework tests
```

## Requirements

- Swift 6.0+
- macOS 13+

## License

MIT
