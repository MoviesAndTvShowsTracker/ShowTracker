import AuthenticationServices
import CryptoKit
import UIKit

struct AppleSignInCredentials: Sendable {
    let identityToken: String
    let nonce: String
    let givenName: String?
    let familyName: String?
}

enum AppleAuth {
    @MainActor
    static func signIn() async throws -> AppleSignInCredentials {
        let nonce = randomNonce()
        let hashed = sha256(nonce)
        return try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleSignInCoordinator(
                rawNonce: nonce,
                continuation: continuation
            )
            AppleSignInCoordinator.retain(delegate)

            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashed

            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            controller.performRequests()
        }
    }

    static func isCancellation(_ error: Error) -> Bool {
        let ns = error as NSError
        return ns.domain == ASAuthorizationError.errorDomain
            && ns.code == ASAuthorizationError.canceled.rawValue
    }

    private static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                randoms = (0..<16).map { _ in UInt8.random(in: 0...255) }
            }
            for value in randoms where remaining > 0 {
                if value < charset.count {
                    result.append(charset[Int(value)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

@MainActor
private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private static var live: AppleSignInCoordinator?

    private let rawNonce: String
    private let continuation: CheckedContinuation<AppleSignInCredentials, Error>
    private var finished = false

    init(rawNonce: String, continuation: CheckedContinuation<AppleSignInCredentials, Error>) {
        self.rawNonce = rawNonce
        self.continuation = continuation
    }

    static func retain(_ coordinator: AppleSignInCoordinator) {
        live = coordinator
    }

    private func finish(_ result: Result<AppleSignInCredentials, Error>) {
        guard !finished else { return }
        finished = true
        Self.live = nil
        continuation.resume(with: result)
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .filter { !$0.isHidden }
        if let key = windows.first(where: \.isKeyWindow) ?? windows.first {
            return key
        }
        return UIWindow()
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(APIError.server(message: "Apple sign-in returned an unexpected credential.", status: 500)))
            return
        }
        guard let tokenData = credential.identityToken,
              let identityToken = String(data: tokenData, encoding: .utf8),
              !identityToken.isEmpty
        else {
            finish(.failure(APIError.server(message: "Apple sign-in did not return an identity token.", status: 401)))
            return
        }

        let given = credential.fullName?.givenName
        let family = credential.fullName?.familyName
        finish(
            .success(
                AppleSignInCredentials(
                    identityToken: identityToken,
                    nonce: rawNonce,
                    givenName: given,
                    familyName: family
                )
            )
        )
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        finish(.failure(error))
    }
}
