import Foundation
import Observation

@MainActor
@Observable
final class AuthStore {
    private enum Keys {
        static let token = "token"
        static let userId = "userId"
        static let email = "email"
        static let firstName = "firstName"
        static let username = "username"
    }

    private(set) var session: AuthSession?
    private(set) var profile: UserProfile?
    private(set) var isRestoring = true
    var errorMessage: String?

    var isAuthenticated: Bool { session?.token.isEmpty == false }

    init() {
        Task { await configureClientAndRestore() }
    }

    func configureClientAndRestore() async {
        await APIClient.shared.configure(
            tokenProvider: {
                KeychainStore.string(forKey: Keys.token)
            },
            onUnauthorized: {
                Task { @MainActor in
                    AuthStore.sharedUnauthorizedHandler?()
                }
            }
        )
        AuthStore.sharedUnauthorizedHandler = { [weak self] in
            self?.clearSession()
        }
        restoreFromKeychain()
        #if DEBUG
        if UITestingFixtures.isEnabled {
            OnboardingStore.hasSeenWelcome = true
            session = AuthSession(
                token: "ui-testing-token",
                userId: "ui-testing",
                email: "jimil@marquee.test",
                firstName: "Jimil",
                username: "jimil"
            )
            isRestoring = false
            return
        }
        #endif
        if session != nil {
            do {
                try await refreshProfile()
            } catch {
                clearSession()
            }
        }
        #if DEBUG
        if session == nil {
            let email = ProcessInfo.processInfo.environment["MARQUEE_DEBUG_EMAIL"]
                ?? Self.launchValue(prefix: "-debugEmail=")
            let password = ProcessInfo.processInfo.environment["MARQUEE_DEBUG_PASSWORD"]
                ?? Self.launchValue(prefix: "-debugPassword=")
            if let email, let password, !email.isEmpty, !password.isEmpty {
                try? await signIn(email: email, password: password)
            }
        }
        #endif
        isRestoring = false
    }

    private static var sharedUnauthorizedHandler: (() -> Void)?

    func signIn(email: String, password: String) async throws {
        errorMessage = nil
        let body = ["email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), "password": password]
        let response: LoginResponse = try await APIClient.shared.post("/users/login", body: body, auth: false)
        guard let token = response.token, let userId = response.userIdString else {
            throw APIError.server(message: response.message ?? "Sign in failed.", status: 401)
        }
        let session = AuthSession(
            token: token,
            userId: userId,
            email: response.email ?? email,
            firstName: response.firstName ?? "",
            username: response.username
        )
        persist(session)
        try await refreshProfile()
    }

    func signUp(email: String, password: String) async throws {
        errorMessage = nil
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let _: SuccessMessage = try await APIClient.shared.post(
            "/users/signup",
            body: ["email": trimmed, "password": password],
            auth: false
        )
        try await signIn(email: trimmed, password: password)
    }

    func signInWithGoogle(idToken: String) async throws {
        errorMessage = nil
        let response: LoginResponse = try await APIClient.shared.post(
            "/users/google",
            body: ["idToken": idToken],
            auth: false
        )
        guard let token = response.token, let userId = response.userIdString else {
            throw APIError.server(message: response.message ?? "Google sign-in failed.", status: 401)
        }
        let session = AuthSession(
            token: token,
            userId: userId,
            email: response.email ?? "",
            firstName: response.firstName ?? "",
            username: response.username
        )
        persist(session)
        try await refreshProfile()
    }

    func signInWithApple(_ credentials: AppleSignInCredentials) async throws {
        errorMessage = nil
        let fullName: AppleFullNameBody? = {
            guard credentials.givenName != nil || credentials.familyName != nil else { return nil }
            return AppleFullNameBody(
                givenName: credentials.givenName ?? "",
                familyName: credentials.familyName ?? ""
            )
        }()
        let response: LoginResponse = try await APIClient.shared.post(
            "/users/apple",
            body: AppleSignInBody(
                identityToken: credentials.identityToken,
                nonce: credentials.nonce,
                fullName: fullName
            ),
            auth: false
        )
        guard let token = response.token, let userId = response.userIdString else {
            throw APIError.server(message: response.message ?? "Apple sign-in failed.", status: 401)
        }
        let session = AuthSession(
            token: token,
            userId: userId,
            email: response.email ?? "",
            firstName: response.firstName ?? "",
            username: response.username
        )
        persist(session)
        try await refreshProfile()
    }

    func forgotPassword(email: String) async throws {
        let _: SuccessMessage = try await APIClient.shared.post(
            "/users/forgot-password",
            body: ["email": email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()],
            auth: false
        )
    }

    func resetPassword(token: String, password: String) async throws {
        let _: SuccessMessage = try await APIClient.shared.post(
            "/users/reset-password",
            body: ["token": token, "password": password],
            auth: false
        )
    }

    func refreshProfile() async throws {
        guard let userId = session?.userId else { return }
        let envelope: UserEnvelope = try await APIClient.shared.get("/users/getUser/\(userId)")
        profile = envelope.found
        if let found = envelope.found {
            session?.email = found.email ?? session?.email ?? ""
            session?.firstName = found.firstName ?? session?.firstName ?? ""
            session?.username = found.username
            if let session { persist(session) }
        }
    }

    /// `currentPassword` is required by the server only when the email changes.
    func updateProfile(firstName: String, lastName: String, email: String, phone: String, currentPassword: String? = nil) async throws {
        struct Body: Encodable {
            let firstName: String
            let lastName: String
            let email: String
            let phonenumber: String
            let currentPassword: String?
        }
        let _: SuccessMessage = try await APIClient.shared.post(
            "/users/updateProfile",
            body: Body(firstName: firstName, lastName: lastName, email: email, phonenumber: phone, currentPassword: currentPassword)
        )
        try await refreshProfile()
    }

    func changePassword(current: String, newPassword: String) async throws {
        struct Body: Encodable {
            let currentPassword: String
            let newPassword: String
        }
        struct Response: Decodable, Sendable {
            let success: Bool?
            let token: String?
        }
        let res: Response = try await APIClient.shared.post(
            "/users/changePassword",
            body: Body(currentPassword: current, newPassword: newPassword)
        )
        // Changing the password ends older sessions; keep this one with the fresh token.
        if let token = res.token, var updated = session {
            updated.token = token
            persist(updated)
        }
    }

    func signOut() {
        GoogleAuth.signOut()
        clearSession()
    }

    func deleteAccount() async throws {
        let _: SuccessMessage = try await APIClient.shared.delete("/users/me")
        signOut()
    }

    private func persist(_ session: AuthSession) {
        self.session = session
        KeychainStore.set(session.token, forKey: Keys.token)
        KeychainStore.set(session.userId, forKey: Keys.userId)
        KeychainStore.set(session.email, forKey: Keys.email)
        KeychainStore.set(session.firstName, forKey: Keys.firstName)
        if let username = session.username {
            KeychainStore.set(username, forKey: Keys.username)
        }
    }

    private func restoreFromKeychain() {
        guard let token = KeychainStore.string(forKey: Keys.token),
              let userId = KeychainStore.string(forKey: Keys.userId) else { return }
        session = AuthSession(
            token: token,
            userId: userId,
            email: KeychainStore.string(forKey: Keys.email) ?? "",
            firstName: KeychainStore.string(forKey: Keys.firstName) ?? "",
            username: KeychainStore.string(forKey: Keys.username)
        )
    }

    private func clearSession() {
        session = nil
        profile = nil
        KeychainStore.remove(Keys.token)
        KeychainStore.remove(Keys.userId)
        KeychainStore.remove(Keys.email)
        KeychainStore.remove(Keys.firstName)
        KeychainStore.remove(Keys.username)
        ResponseCache.clearAll()
        APIClient.shared.clearCachedResponses()
    }

    #if DEBUG
    private static func launchValue(prefix: String) -> String? {
        guard let raw = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix(prefix) }) else {
            return nil
        }
        let value = String(raw.dropFirst(prefix.count))
        return value.isEmpty ? nil : value
    }
    #endif
}
