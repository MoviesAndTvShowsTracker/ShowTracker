import Foundation
import UserNotifications

/// Schedules local alerts for upcoming episodes of tracked shows.
/// Remote APNs send can layer on later; this delivers P0 value today.
enum EpisodeAlertScheduler {
    private static let prefix = "marquee.episode."

    static func refresh(schedule: [ScheduleEpisode], enabled: Bool) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let stale = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)

        guard enabled else { return }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else { return }

        let calendar = Calendar.current
        for item in schedule.prefix(20) {
            guard let day = parseDay(item.airDate) else { continue }
            // Fire at 9:00 local on air day — calm, not spammy.
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = 9
            comps.minute = 0
            guard let fire = calendar.date(from: comps), fire > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = item.title
            let ep = item.episodeName.map { " · \($0)" } ?? ""
            content.body = "S\(item.season)E\(item.episode)\(ep) lands today."
            content.sound = .default
            content.userInfo = ["tvId": item.tvId]

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fire),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "\(prefix)\(item.id)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private static func parseDay(_ raw: String) -> Date? {
        let parts = raw.split(separator: "-")
        guard parts.count >= 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        return Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
    }
}
