import UIKit

@MainActor
enum Haptics {
    private static let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let notifyGenerator = UINotificationFeedbackGenerator()

    static func prepare() {
        guard enabled else { return }
        lightGenerator.prepare()
        mediumGenerator.prepare()
        notifyGenerator.prepare()
    }

    static func light() {
        guard enabled else { return }
        lightGenerator.impactOccurred()
    }

    static func medium() {
        guard enabled else { return }
        mediumGenerator.impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        notifyGenerator.notificationOccurred(.success)
    }

    private static var enabled: Bool {
        if UserDefaults.standard.object(forKey: "marquee.haptics") == nil { return true }
        return UserDefaults.standard.bool(forKey: "marquee.haptics")
    }
}
