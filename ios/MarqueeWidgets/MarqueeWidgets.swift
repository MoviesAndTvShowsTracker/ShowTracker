import WidgetKit
import SwiftUI

private enum Snapshot {
    private static var suite: UserDefaults {
        UserDefaults(suiteName: "group.com.jimil.marquee") ?? .standard
    }

    static var continueTitle: String { suite.string(forKey: "continueTitle") ?? "Continue watching" }
    static var weekFilms: Int { suite.integer(forKey: "weekFilms") }
    static var weekEpisodes: Int { suite.integer(forKey: "weekEpisodes") }
    static var weekMins: Int { suite.integer(forKey: "weekMins") }
}

struct ContinueEntry: TimelineEntry {
    let date: Date
    let title: String
}

struct ContinueProvider: TimelineProvider {
    func placeholder(in context: Context) -> ContinueEntry {
        ContinueEntry(date: .now, title: "Your next episode")
    }

    func getSnapshot(in context: Context, completion: @escaping (ContinueEntry) -> Void) {
        completion(ContinueEntry(date: .now, title: Snapshot.continueTitle))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ContinueEntry>) -> Void) {
        let entry = ContinueEntry(date: .now, title: Snapshot.continueTitle)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 30))))
    }
}

struct ContinueWatchingWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ContinueWatchingWidget", provider: ContinueProvider()) { entry in
            VStack(alignment: .leading, spacing: 8) {
                Text("CONTINUE")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(entry.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(3)
                Spacer(minLength: 0)
                Text("Open Marquee")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.86, green: 0.27, blue: 0.42))
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Continue Watching")
        .description("Jump back into the show you’re mid-season.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct WeekEntry: TimelineEntry {
    let date: Date
    let films: Int
    let episodes: Int
    let mins: Int
}

struct WeekProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeekEntry {
        WeekEntry(date: .now, films: 2, episodes: 5, mins: 240)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeekEntry) -> Void) {
        completion(WeekEntry(date: .now, films: Snapshot.weekFilms, episodes: Snapshot.weekEpisodes, mins: Snapshot.weekMins))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeekEntry>) -> Void) {
        let entry = WeekEntry(date: .now, films: Snapshot.weekFilms, episodes: Snapshot.weekEpisodes, mins: Snapshot.weekMins)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60 * 60))))
    }
}

struct WeekStatsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "WeekStatsWidget", provider: WeekProvider()) { entry in
            VStack(alignment: .leading, spacing: 10) {
                Text("THIS WEEK")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                HStack {
                    metric("Films", entry.films)
                    metric("Eps", entry.episodes)
                    metric("Min", entry.mins)
                }
            }
            .padding()
            .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Week Stats")
        .description("Films, episodes, and minutes logged this week.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@main
struct MarqueeWidgetsBundle: WidgetBundle {
    var body: some Widget {
        ContinueWatchingWidget()
        WeekStatsWidget()
    }
}
