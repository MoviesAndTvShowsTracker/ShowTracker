import Foundation

actor APIClient {
    static let shared = APIClient(session: APIClient.makeSession())

    /// The app's session: a real response cache (ETag revalidation, `Cache-Control`), a request
    /// timeout suited to a phone, and waiting briefly for a connection instead of failing at once.
    static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 40
        config.waitsForConnectivity = true
        config.requestCachePolicy = .useProtocolCachePolicy
        config.urlCache = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024)
        return URLSession(configuration: config)
    }

    private struct Raw: Sendable {
        let data: Data
        let status: Int
    }

    private nonisolated let session: URLSession
    private let encoder = JSONEncoder()
    /// Waits before each GET retry; GETs retry on brief failures (Render restarts, a dropped connection).
    private let retryDelays: [Duration]
    /// Identical GETs in flight share one request.
    private var inFlight: [String: Task<Raw, Error>] = [:]

    private var tokenProvider: (@Sendable () -> String?)?
    private var onUnauthorized: (@Sendable () -> Void)?

    init(session: URLSession = .shared, retryDelays: [Duration] = [.milliseconds(400), .milliseconds(1200)]) {
        self.session = session
        self.retryDelays = retryDelays
    }

    /// Removes every cached API response (on sign-out, account deletion or an expired session).
    nonisolated func clearCachedResponses() {
        session.configuration.urlCache?.removeAllCachedResponses()
    }

    func configure(
        tokenProvider: @escaping @Sendable () -> String?,
        onUnauthorized: @escaping @Sendable () -> Void
    ) {
        self.tokenProvider = tokenProvider
        self.onUnauthorized = onUnauthorized
    }

    nonisolated func get<T: Decodable & Sendable>(_ path: String, query: [URLQueryItem] = [], auth: Bool = true) async throws -> T {
        let raw = try await sharedGet(path: path, query: query, auth: auth)
        return try Self.decode(raw)
    }

    nonisolated func post<Body: Encodable & Sendable, T: Decodable & Sendable>(_ path: String, body: Body, auth: Bool = true) async throws -> T {
        let raw = try await send(path: path, method: "POST", body: body, auth: auth)
        return try Self.decode(raw)
    }

    nonisolated func delete<T: Decodable & Sendable>(_ path: String, auth: Bool = true) async throws -> T {
        let raw = try await send(path: path, method: "DELETE", body: Optional<EmptyBody>.none, auth: auth)
        return try Self.decode(raw)
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
        return try Self.decode(try await perform(urlRequest))
    }

    private struct EmptyBody: Encodable, Sendable {}

    // MARK: Requests

    private func sharedGet(path: String, query: [URLQueryItem], auth: Bool) async throws -> Raw {
        let request = try makeURLRequest(path: path, method: "GET", query: query, auth: auth)
        let key = (request.url?.absoluteString ?? path) + "|" + (request.value(forHTTPHeaderField: "Authorization") ?? "")
        if let running = inFlight[key] { return try await running.value }
        let task = Task { try await self.performWithRetry(request) }
        inFlight[key] = task
        defer { inFlight[key] = nil }
        return try await task.value
    }

    private func send<Body: Encodable & Sendable>(path: String, method: String, body: Body?, auth: Bool) async throws -> Raw {
        var request = try makeURLRequest(path: path, method: method, query: [], auth: auth)
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        return try await perform(request)
    }

    private func performWithRetry(_ request: URLRequest) async throws -> Raw {
        var attempt = 0
        while true {
            do {
                return try await perform(request)
            } catch where attempt < retryDelays.count && Self.isRetryable(error) {
                try await Task.sleep(for: retryDelays[attempt])
                attempt += 1
            }
        }
    }

    /// Brief failures worth one more try on a read: a gateway error or a dropped connection.
    static func isRetryable(_ error: Error) -> Bool {
        switch error {
        case APIError.server(_, let status):
            return status == 502 || status == 503 || status == 504
        case APIError.transport(let underlying):
            let code = (underlying as? URLError)?.code
            return code == .timedOut || code == .networkConnectionLost || code == .cannotConnectToHost
        default:
            return false
        }
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

    private func perform(_ request: URLRequest) async throws -> Raw {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else { throw APIError.empty }
        if http.statusCode == 401 {
            // Only a 401 for the token we hold now ends the session; one for an older token
            // (e.g. a request in flight while the password changed) doesn't.
            let sent = request.value(forHTTPHeaderField: "Authorization")
            if let sent, sent == tokenProvider?().map({ "Bearer \($0)" }) {
                onUnauthorized?()
            }
            throw APIError.unauthorized
        }
        if !(200..<300).contains(http.statusCode) {
            if let err = try? JSONDecoder().decode(APIMessage.self, from: data) {
                throw APIError.server(message: err.bestMessage, status: http.statusCode)
            }
            throw APIError.server(message: "Request failed (\(http.statusCode))", status: http.statusCode)
        }
        if Freshness.invalidates(method: request.httpMethod ?? "GET", path: request.url?.path ?? "") {
            Freshness.shared.invalidateAll()
        }
        return Raw(data: data, status: http.statusCode)
    }

    /// Decoding runs on the caller's task, not inside the actor, so responses don't queue behind each other.
    private static func decode<T: Decodable>(_ raw: Raw) throws -> T {
        if T.self == EmptyResponse.self {
            return EmptyResponse() as! T
        }
        if raw.data.isEmpty, T.self == SuccessMessage.self {
            return SuccessMessage(success: true, message: nil) as! T
        }
        do {
            return try JSONDecoder().decode(T.self, from: raw.data)
        } catch {
            throw APIError.decoding(error)
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
