import Foundation

struct TGContainer<T: Decodable & Sendable>: Decodable, Sendable {
    let ok: Bool
    let result: T?
    let errorCode: Int?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case ok
        case result
        case errorCode = "error_code"
        case description
    }
}
