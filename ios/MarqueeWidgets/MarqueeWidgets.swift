import WidgetKit
import SwiftUI

private enum MarqueeWidgetColor {
    static let olive = Color(red: 61 / 255, green: 59 / 255, blue: 46 / 255)
    static let oliveSoft = Color(red: 61 / 255, green: 59 / 255, blue: 46 / 255).opacity(0.12)
    static let hibiscus = Color(red: 1, green: 79 / 255, blue: 139 / 255)
    static let parchment = Color(red: 229 / 255, green: 229 / 255, blue: 222 / 255)
    static let elevated = Color(red: 243 / 255, green: 243 / 255, blue: 238 / 255)
    static let inkMuted = olive.opacity(0.58)
}

private enum Snapshot {
    private static var suite: UserDefaults {
        UserDefaults(suiteName: "group.com.jimil.marquee") ?? .standard
    }

    static var continueTitle: String {
        suite.string(forKey: "continueTitle") ?? "Continue watching"
    }

    static var continueSubtitle: String {
        suite.string(forKey: "continueSubtitle") ?? "Open Marquee"
    }

    static var weekFilms: Int { suite.integer(forKey: "weekFilms") }
    static var weekEpisodes: Int { suite.integer(forKey: "weekEpisodes") }
    static var weekMins: Int { suite.integer(forKey: "weekMins") }
    static var weekStreak: Int { suite.integer(forKey: "weekStreak") }

    static func formatMinutes(_ mins: Int) -> String {
        if mins <= 0 { return "0m" }
        let hours = mins / 60
        let rem = mins % 60
        if hours >= 24 {
            let days = hours / 24
            let h = hours % 24
            return h > 0 ? "\(days)d \(h)h" : "\(days)d"
        }
        if hours > 0 { return rem > 0 ? "\(hours)h \(rem)m" : "\(hours)h" }
        return "\(mins)m"
    }
}

struct ContinueEntry: TimelineEntry {
    let date: Date
    let title: String
    let subtitle: String
}

struct ContinueProvider: TimelineProvider {
    func placeholder(in context: Context) -> ContinueEntry {
        ContinueEntry(date: .now, title: "Your next episode", subtitle: "S1E1 · Ready when you are")
    }

    func getSnapshot(in context: Context, completion: @escaping (ContinueEntry) -> Void) {
        completion(
            ContinueEntry(
                date: .now,
                title: Snapshot.continueTitle,
                subtitle: Snapshot.continueSubtitle
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ContinueEntry>) -> Void) {
        let entry = ContinueEntry(
            date: .now,
            title: Snapshot.continueTitle,
            subtitle: Snapshot.continueSubtitle
        )
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 30))))
    }
}

struct ContinueWatchingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ContinueWatchingWidget", provider: ContinueProvider()) { entry in
            ContinueWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            MarqueeWidgetColor.elevated,
                            MarqueeWidgetColor.parchment
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("Up Next")
        .description("Jump straight into the episode you’re mid-season.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct ContinueWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ContinueEntry

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemMedium ? 10 : 8) {
            HStack {
                Text("UP NEXT")
                    .font(.caption2.weight(.bold))
                    .tracking(1.0)
                    .foregroundStyle(MarqueeWidgetColor.hibiscus)
                Spacer()
                Text("Marquee")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MarqueeWidgetColor.inkMuted)
            }

            Text(entry.title)
                .font(family == .systemMedium ? .title3.weight(.bold) : .headline.weight(.bold))
                .foregroundStyle(MarqueeWidgetColor.olive)
                .lineLimit(family == .systemMedium ? 2 : 3)
                .minimumScaleFactor(0.85)

            Text(entry.subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(MarqueeWidgetColor.hibiscus)
                .lineLimit(2)

            Spacer(minLength: 0)

            Text("Continue")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(MarqueeWidgetColor.hibiscus, in: Capsule())
        }
        .padding(14)
    }
}

struct WeekEntry: TimelineEntry {
    let date: Date
    let films: Int
    let episodes: Int
    let mins: Int
    let streak: Int
}

struct WeekProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekEntry {
        WeekEntry(date: .now, films: 2, episodes: 5, mins: 240, streak: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekEntry) -> Void) {
        completion(
            WeekEntry(
                date: .now,
                films: Snapshot.weekFilms,
                episodes: Snapshot.weekEpisodes,
                mins: Snapshot.weekMins,
                streak: Snapshot.weekStreak
            )
        )
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekEntry>) -> Void) {
        let entry = WeekEntry(
            date: .now,
            films: Snapshot.weekFilms,
            episodes: Snapshot.weekEpisodes,
            mins: Snapshot.weekMins,
            streak: Snapshot.weekStreak
        )
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 60))))
    }
}

struct WeekStatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeekStatsWidget", provider: WeekProvider()) { entry in
            WeekWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [
                            MarqueeWidgetColor.olive.opacity(0.14),
                            MarqueeWidgetColor.hibiscus.opacity(0.12),
                            MarqueeWidgetColor.elevated
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
        .configurationDisplayName("This Week")
        .description("Films, episodes, time, and streak from your diary.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private struct WeekWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: WeekEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("THIS WEEK")
                .font(.caption2.weight(.bold))
                .tracking(1.0)
                .foregroundStyle(MarqueeWidgetColor.hibiscus)

            Text(Snapshot.formatMinutes(entry.mins))
                .font(.system(size: family == .systemMedium ? 30 : 26, weight: .bold, design: .rounded))
                .foregroundStyle(MarqueeWidgetColor.olive)
                .monospacedDigit()
                .minimumScaleFactor(0.8)

            if family == .systemMedium {
                HStack(spacing: 8) {
                    weekCell(value: "\(entry.films)", label: "Films", tint: MarqueeWidgetColor.hibiscus)
                    weekCell(value: "\(entry.episodes)", label: "Eps", tint: MarqueeWidgetColor.olive)
                    weekCell(value: Snapshot.formatMinutes(entry.mins), label: "Time", tint: MarqueeWidgetColor.hibiscus)
                }
            } else {
                HStack(spacing: 12) {
                    smallMetric("\(entry.films)", "Films")
                    smallMetric("\(entry.episodes)", "Eps")
                }
            }

            Spacer(minLength: 0)

            if entry.streak > 0 {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(MarqueeWidgetColor.hibiscus)
                    Text(entry.streak == 1 ? "1-day streak" : "\(entry.streak)-day streak")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(MarqueeWidgetColor.olive)
                }
            }
        }
        .padding(14)
    }

    private func weekCell(value: String, label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MarqueeWidgetColor.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func smallMetric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(MarqueeWidgetColor.olive)
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(MarqueeWidgetColor.inkMuted)
        }
    }
}

@main
struct MarqueeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ContinueWatchingWidget()
        WeekStatsWidget()
    }
}
