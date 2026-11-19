import Foundation

actor APIClient {
    static let shared = APIClient()

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var tokenProvider: (@Sendable () -> String?)?
    private var onUnauthorized: (@Sendable () -> Void)?

    init(session: URLSession = .shared) {
        self.session = session
    }

    func configure(
        tokenProvider: @escaping @Sendable () -> String?,
        onUnauthorized: @escaping @Sendable () -> Void
    ) {
        self.tokenProvider = tokenProvider
        self.onUnauthorized = onUnauthorized
    }

    func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = [], auth: Bool = true) async throws -> T {
        try await request(path, method: "GET", query: query, body: Optional<EmptyBody>.none, auth: auth)
    }

    func post<Body: Encodable & Sendable, T: Decodable & Sendable>(_ path: String, body: Body, auth: Bool = true) async throws -> T {
        try await request(path, method: "POST", query: [], body: body, auth: auth)
    }

    func delete<T: Decodable & Sendable>(_ path: String, auth: Bool = true) async throws -> T {
        try await request(path, method: "DELETE", query: [], body: Optional<EmptyBody>.none, auth: auth)
    }

    func upload<T: Decodable & Sendable>(_ path: String, fileURL: URL, fieldName: String = "file", auth: Bool = true) async throws -> T {
        let boundary = "Boundary-\(UUID().uuidString)"
        var urlRequest = try makeURLRequest(path: path, method: "POST", query: [], auth: auth)
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let filename = fileURL.lastPathComponent
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/zip\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        urlRequest.httpBody = body
        return try await perform(urlRequest)
    }

    private struct EmptyBody: Encodable, Sendable {}

    private func request<Body: Encodable & Sendable, T: Decodable & Sendable>(
        _ path: String,
        method: String,
        query: [URLQueryItem],
        body: Body?,
        auth: Bool
    ) async throws -> T {
        var urlRequest = try makeURLRequest(path: path, method: method, query: query, auth: auth)
        if let body {
            urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.httpBody = try encoder.encode(body)
        }
        return try await perform(urlRequest)
    }

    private func makeURLRequest(path: String, method: String, query: [URLQueryItem], auth: Bool) throws -> URLRequest {
        let base = AppConfig.apiBaseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let cleanPath = path.hasPrefix("/") ? path : "/\(path)"
        guard var comps = URLComponents(string: base + cleanPath) else { throw APIError.invalidURL }
        if !query.isEmpty { comps.queryItems = query }
        guard let url = comps.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if auth, let token = tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(TimeZone.current.identifier, forHTTPHeaderField: "X-Timezone")
        request.setValue("ios", forHTTPHeaderField: "X-Client")
        if let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            request.setValue(build, forHTTPHeaderField: "X-Client-Build")
        }
        return request
    }

    private func perform<T: Decodable & Sendable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.empty }
            if http.statusCode == 401 {
                onUnauthorized?()
                throw APIError.unauthorized
            }
            if !(200..<300).contains(http.statusCode) {
                if let err = try? decoder.decode(APIMessage.self, from: data) {
                    throw APIError.server(message: err.bestMessage, status: http.statusCode)
                }
                throw APIError.server(message: "Request failed (\(http.statusCode))", status: http.statusCode)
            }
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            if data.isEmpty, T.self == SuccessMessage.self {
                return SuccessMessage(success: true, message: nil) as! T
            }
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decoding(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.transport(error)
        }
    }
}

struct APIMessage: Decodable, Sendable {
    let success: Bool?
    let message: String?
    let err: String?
    var bestMessage: String { message ?? err ?? "Something went wrong." }
}

struct EmptyResponse: Decodable, Sendable {
    init() {}
}
