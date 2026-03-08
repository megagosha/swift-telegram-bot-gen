import Foundation
import TGBotAPI

enum TGUpdateFixtures {
    private static let decoder = JSONDecoder()

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
        return decodeOnLargeStack(json)
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
        return decodeOnLargeStack(json)
    }

    static func empty() -> TGUpdate {
        return decodeOnLargeStack(#"{"update_id": 3}"#)
    }

    /// TGUpdate is ~65KB — decoding it in JSONDecoder requires multiple
    /// stack-allocated copies which overflow the default test thread stack.
    /// Run the decode on a thread with a 2MB stack.
    private static func decodeOnLargeStack(_ json: String) -> TGUpdate {
        let data = Data(json.utf8)
        nonisolated(unsafe) let result = UnsafeMutablePointer<TGUpdate>.allocate(capacity: 1)
        let sema = DispatchSemaphore(value: 0)
        let thread = Thread {
            do {
                result.initialize(to: try decoder.decode(TGUpdate.self, from: data))
            } catch {
                fatalError("Failed to decode TGUpdate fixture: \(error)")
            }
            sema.signal()
        }
        thread.stackSize = 2 * 1024 * 1024
        thread.start()
        sema.wait()
        let value = result.move()
        result.deallocate()
        return value
    }

    private static func jsonString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let encoded = String(data: data, encoding: .utf8) else {
            return "\"\(value)\""
        }
        return encoded
    }
}
