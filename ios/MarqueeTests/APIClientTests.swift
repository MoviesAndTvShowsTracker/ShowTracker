import XCTest
@testable import Marquee

/// Answers every request from `handler` and counts them, so tests see real network behaviour.
final class StubURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, Data, TimeInterval))?
    private static let lock = NSLock()
    nonisolated(unsafe) private static var _count = 0
    static var count: Int { lock.lock(); defer { lock.unlock() }; return _count }
    static func reset() { lock.lock(); _count = 0; lock.unlock() }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.lock(); Self._count += 1; Self.lock.unlock()
        let (status, data, delay) = Self.handler?(request) ?? (200, Data("{}".utf8), 0)
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [self] in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

final class APIClientTests: XCTestCase {
    private func client() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return APIClient(session: URLSession(configuration: config), retryDelays: [.zero, .zero])
    }

    override func setUp() {
        StubURLProtocol.reset()
        StubURLProtocol.handler = nil
    }

    func testConcurrentIdenticalGetsShareOneRequest() async throws {
        StubURLProtocol.handler = { _ in (200, Data(#"{"success":true,"message":"hi"}"#.utf8), 0.1) }
        let api = client()
        async let a: SuccessMessage = api.get("/api/home")
        async let b: SuccessMessage = api.get("/api/home")
        async let c: SuccessMessage = api.get("/api/home")
        let results = try await [a, b, c]
        XCTAssertEqual(results.map(\.message), ["hi", "hi", "hi"])
        XCTAssertEqual(StubURLProtocol.count, 1)
    }

    func testGetRetriesAfter503() async throws {
        StubURLProtocol.handler = { _ in
            StubURLProtocol.count == 1 ? (503, Data("{}".utf8), 0) : (200, Data(#"{"success":true}"#.utf8), 0)
        }
        let res: SuccessMessage = try await client().get("/api/home")
        XCTAssertEqual(res.success, true)
        XCTAssertEqual(StubURLProtocol.count, 2)
    }

    func testGetGivesUpAfterTwoRetries() async {
        StubURLProtocol.handler = { _ in (502, Data("{}".utf8), 0) }
        do {
            let _: SuccessMessage = try await client().get("/api/home")
            XCTFail("should throw")
        } catch APIError.server(_, let status) {
            XCTAssertEqual(status, 502)
        } catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(StubURLProtocol.count, 3)
    }

    func testPostIsNeverRetried() async {
        StubURLProtocol.handler = { _ in (503, Data("{}".utf8), 0) }
        do {
            let _: SuccessMessage = try await client().post("/api/tv/episodes/mark", body: ["tvId": "1"])
            XCTFail("should throw")
        } catch {}
        XCTAssertEqual(StubURLProtocol.count, 1)
    }

    func testClientErrorsAreNotRetried() async {
        StubURLProtocol.handler = { _ in (404, Data(#"{"message":"nope"}"#.utf8), 0) }
        do {
            let _: SuccessMessage = try await client().get("/api/missing")
            XCTFail("should throw")
        } catch {}
        XCTAssertEqual(StubURLProtocol.count, 1)
    }
}
