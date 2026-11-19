import Foundation
import UIKit
import UserNotifications

@MainActor
enum PushRegistration {
    private static let tokenKey = "marquee.apns.token"

    /// Explicit opt-in (e.g. Settings). Avoid calling from Home onAppear.
    static func requestAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    static func syncIfAuthorized() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
                return
            }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
                syncIfNeeded()
            }
        }
    }

    static func didRegister(deviceToken: Data) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenKey)
        Task { await upload(token: token) }
    }

    static func syncIfNeeded() {
        guard let token = UserDefaults.standard.string(forKey: tokenKey), !token.isEmpty else { return }
        Task { await upload(token: token) }
    }

    private static func upload(token: String) async {
        struct Body: Encodable {
            let token: String
            let platform: String
            let appVersion: String
        }
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        _ = try? await APIClient.shared.post(
            "/api/devices/register",
            body: Body(token: token, platform: "ios", appVersion: version)
        ) as SuccessMessage
    }
}
