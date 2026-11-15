import AuthenticationServices
import CryptoKit
import UIKit

enum GoogleAuth {
    @MainActor
    static func configure() {}

    @MainActor
    static func handle(_ url: URL) -> Bool {
        InAppGoogleSession.resume(url)
    }

    @MainActor
    static func signIn() async throws -> String {
        let flow = try GoogleOAuthFlow.make()
        let window = try presentationWindow()
        let callback = try await InAppGoogleSession.present(url: flow.authorizationURL, window: window)
        return try await flow.exchange(callback: callback)
    }

    @MainActor
    static func signOut() {}

    static func isCancellation(_ error: Error) -> Bool {
        if let api = error as? APIError, case .unauthorized = api { return true }
        let ns = error as NSError
        return ns.domain == ASWebAuthenticationSessionError.errorDomain
            && ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue
    }

    @MainActor
    private static func presentationWindow() throws -> UIWindow {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { !$0.isHidden }
        if let window = windows.first(where: \.isKeyWindow) ?? windows.first {
            return window
        }
        throw APIError.server(message: "Could not present Google sign-in.", status: 500)
    }
}

private struct GoogleOAuthFlow {
    let authorizationURL: URL
    let redirectURI: String
    let state: String
    let verifier: String
    let clientID: String
    let audience: String

    static func make() throws -> GoogleOAuthFlow {
        let clientID = AppConfig.googleIOSClientID
        let audience = AppConfig.googleWebClientID
        guard !clientID.isEmpty else {
            throw APIError.server(message: "Google sign-in is not configured.", status: 503)
        }
        let redirectURI = "\(AppConfig.googleURLScheme):/oauth2callback"
        let state = randomToken()
        let verifier = randomToken()
        let challenge = Data(SHA256.hash(data: Data(verifier.utf8))).base64URLEncoded
        var comps = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        var items = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "openid email profile"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "include_granted_scopes", value: "true")
        ]
        if !audience.isEmpty {
            items.append(URLQueryItem(name: "audience", value: audience))
        }
        comps.queryItems = items
        guard let url = comps.url else { throw APIError.invalidURL }
        return GoogleOAuthFlow(
            authorizationURL: url,
            redirectURI: redirectURI,
            state: state,
            verifier: verifier,
            clientID: clientID,
            audience: audience
        )
    }

    func exchange(callback: URL) async throws -> String {
        let items = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let values = Dictionary(uniqueKeysWithValues: items.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        })
        if values["error"] == "access_denied" {
            throw APIError.unauthorized
        }
        guard values["state"] == state else {
            throw APIError.server(message: "Google sign-in could not be verified.", status: 401)
        }
        guard let code = values["code"], !code.isEmpty else {
            throw APIError.server(message: "Google did not return a sign-in code.", status: 401)
        }

        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var body = [
            "code": code,
            "client_id": clientID,
            "redirect_uri": redirectURI,
            "grant_type": "authorization_code",
            "code_verifier": verifier
        ]
        if !audience.isEmpty {
            body["audience"] = audience
        }
        request.httpBody = formURLEncoded(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw APIError.server(message: "Google sign-in failed.", status: status)
        }
        let payload = try JSONDecoder().decode(GoogleTokenResponse.self, from: data)
        guard let idToken = payload.id_token, !idToken.isEmpty else {
            throw APIError.server(message: "Google did not return an ID token.", status: 401)
        }
        return idToken
    }

    private static func randomToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncoded
    }
}

private struct GoogleTokenResponse: Decodable {
    let id_token: String?
}

/// System auth sheet over Marquee — not the Google SDK, which was hopping out of the app.
@MainActor
private final class InAppGoogleSession: NSObject, ASWebAuthenticationPresentationContextProviding {
    private static var current: InAppGoogleSession?

    private var continuation: CheckedContinuation<URL, Error>?
    private var authSession: ASWebAuthenticationSession?
    private var window: UIWindow?

    static func present(url: URL, window: UIWindow) async throws -> URL {
        current?.finish(callback: nil, error: APIError.unauthorized)
        let session = InAppGoogleSession()
        current = session
        session.window = window

        return try await withCheckedThrowingContinuation { continuation in
            session.continuation = continuation
            let auth = ASWebAuthenticationSession(
                url: url,
                callback: .customScheme(AppConfig.googleURLScheme)
            ) { callback, error in
                Task { @MainActor in
                    session.finish(callback: callback, error: error)
                }
            }
            auth.presentationContextProvider = session
            auth.prefersEphemeralWebBrowserSession = false
            session.authSession = auth
            if !auth.start() {
                session.finish(
                    callback: nil,
                    error: APIError.server(message: "Could not start Google sign-in.", status: 500)
                )
            }
        }
    }

    static func resume(_ url: URL) -> Bool {
        guard url.scheme?.caseInsensitiveCompare(AppConfig.googleURLScheme) == .orderedSame else {
            return false
        }
        current?.finish(callback: url, error: nil)
        return true
    }

    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        if let window { return window }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { !$0.isHidden }!
    }

    private func finish(callback: URL?, error: Error?) {
        guard let continuation else { return }
        self.continuation = nil
        authSession = nil
        if Self.current === self { Self.current = nil }

        if let error {
            let ns = error as NSError
            if ns.domain == ASWebAuthenticationSessionError.errorDomain,
               ns.code == ASWebAuthenticationSessionError.canceledLogin.rawValue {
                continuation.resume(throwing: APIError.unauthorized)
            } else {
                continuation.resume(throwing: error)
            }
            return
        }
        if let callback {
            continuation.resume(returning: callback)
            return
        }
        continuation.resume(throwing: APIError.unauthorized)
    }
}

private func formURLEncoded(_ pairs: [String: String]) -> Data {
    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: "&+=?")
    let body = pairs.map { key, value in
        let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
        let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        return "\(encodedKey)=\(encodedValue)"
    }
    .joined(separator: "&")
    return Data(body.utf8)
}

private extension Data {
    var base64URLEncoded: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
