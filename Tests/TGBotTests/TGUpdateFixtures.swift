import Foundation
import TGBotAPI

enum TGUpdateFixtures {

    static func withMessage(text: String) -> TGUpdate {
        let json = """
        {
            "update_id": 1,
            "message": {
                "message_id": 1,
                "date": 0,
                "chat": {"id": 1, "type": "private"},
                "text": \(jsonString(text))
            }
        }
        """
        return decode(json)
    }

    static func withCallbackQuery(data: String = "test") -> TGUpdate {
        let json = """
        {
            "update_id": 2,
            "callback_query": {
                "id": "1",
                "from": {"id": 1, "is_bot": false, "first_name": "Test"},
                "chat_instance": "inst",
                "data": \(jsonString(data))
            }
        }
        """
        return decode(json)
    }

    static func empty() -> TGUpdate {
        return decode(#"{"update_id": 3}"#)
    }

    private static func decode(_ json: String) -> TGUpdate {
        guard let data = json.data(using: .utf8) else {
            fatalError("Failed to encode fixture JSON as UTF-8")
        }
        do {
            return try JSONDecoder().decode(TGUpdate.self, from: data)
        } catch {
            fatalError("Failed to decode TGUpdate fixture: \(error)")
        }
    }

    private static func jsonString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8) else {
            return "\"\(value)\""
        }
        return encoded
    }
}
