import Foundation

public struct APISpec: Codable, Sendable {
    public let version: String
    public let releaseDate: String
    public let changelog: String
    public let methods: [String: APIMethod]
    public let types: [String: APIType]

    enum CodingKeys: String, CodingKey {
        case version
        case releaseDate = "release_date"
        case changelog
        case methods
        case types
    }
}

public struct APIType: Codable, Sendable {
    public let name: String
    public let href: String
    public let description: [String]
    public let fields: [APIField]?
    public let subtypes: [String]?
    public let subtypeOf: [String]?

    enum CodingKeys: String, CodingKey {
        case name, href, description, fields, subtypes
        case subtypeOf = "subtype_of"
    }
}

public struct APIMethod: Codable, Sendable {
    public let name: String
    public let href: String
    public let description: [String]
    public let returns: [String]
    public let fields: [APIField]?
}

public struct APIField: Codable, Sendable {
    public let name: String
    public let types: [String]
    public let required: Bool
    public let description: String
}
