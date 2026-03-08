import TGBot
import TGBotAPI

let token = "7926680237:AAFDwRljICjsPaKxXYL10NrAm2EwYY-GlZU"

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
