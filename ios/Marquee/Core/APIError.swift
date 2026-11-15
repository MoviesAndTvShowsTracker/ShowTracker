import Foundation

enum APIError: LocalizedError {
    case invalidURL
    case unauthorized
    case server(message: String, status: Int)
    case decoding(Error)
    case transport(Error)
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request."
        case .unauthorized: return "Session expired. Sign in again."
        case .server(let message, _): return message
        case .decoding: return "Could not read the server response."
        case .transport(let error): return error.localizedDescription
        case .empty: return "Nothing to show."
        }
    }
}
