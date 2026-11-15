import UIKit

enum Haptics {
    static func light() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private static var enabled: Bool {
        if UserDefaults.standard.object(forKey: "marquee.haptics") == nil { return true }
        return UserDefaults.standard.bool(forKey: "marquee.haptics")
    }
}
