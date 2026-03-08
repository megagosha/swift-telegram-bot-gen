import Foundation
import TGBot
import TGBotAPI

guard let token = ProcessInfo.processInfo.environment["BOT_TOKEN"] else {
    fatalError("BOT_TOKEN environment variable is not set")
}

let bot = TGBot(
    token: token,
    handlers: [
        TGMessageHandler { msg, client in
            let _: TGMessage = try await client.post(
                "sendMessage",
                params: TGSendMessageParams(
                    chatId: .int(msg.chat.id),
                    text: "Yo!"
                )
            )
        }
    ]
)

await bot.run()
