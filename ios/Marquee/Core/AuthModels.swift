import Foundation

struct AuthSession: Codable, Equatable, Sendable{
    var token: String
    var userId: String
    var email: String
    var firstName: String
    var username: String?
}

struct LoginResponse: Decodable, Sendable{
    let success: Bool?
    let token: String?
    let userId: FlexibleID?
    let email: String?
    let firstName: String?
    let username: String?
    let message: String?

    var userIdString: String? {
        userId?.stringValue
    }
}

enum FlexibleID: Codable, Equatable, Hashable, Sendable{
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let i = try? c.decode(Int.self) {
            self = .int(i)
        } else {
            throw DecodingError.typeMismatch(FlexibleID.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected string or int id"))
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .int(let i): try c.encode(i)
        }
    }

    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        }
    }
}

struct UserEnvelope: Decodable, Sendable{
    let success: Bool?
    let found: UserProfile?
}

struct UserProfile: Decodable, Equatable, Identifiable, Sendable{
    var id: String { _id.stringValue }
    let _id: FlexibleID
    var email: String?
    var firstName: String?
    var lastName: String?
    var username: String?
    var phonenumber: String?
    var createdAt: String?
}

struct SuccessMessage: Decodable, Sendable{
    let success: Bool?
    let message: String?
}

struct AppleFullNameBody: Encodable, Sendable {
    let givenName: String
    let familyName: String
}

struct AppleSignInBody: Encodable, Sendable {
    let identityToken: String
    let nonce: String
    let fullName: AppleFullNameBody?
}

