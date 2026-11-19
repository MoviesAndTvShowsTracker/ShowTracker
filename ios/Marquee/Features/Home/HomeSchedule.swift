import Foundation

struct ScheduleEpisode: Identifiable, Hashable {
    var id: String { "\(tvId)-\(season)-\(episode)" }
    let tvId: Int
    let title: String
    let posterPath: String?
    let season: Int
    let episode: Int
    let episodeName: String?
    let airDate: String
}

enum HomeScheduleBuilder {
    static func upcoming(from tracks: [TrackingRecord], withinDays: Int = 14) async -> [ScheduleEpisode] {
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: withinDays, to: today) ?? today
        var out: [ScheduleEpisode] = []

        await withTaskGroup(of: [ScheduleEpisode].self) { group in
            for track in tracks.prefix(16) {
                guard let tvId = Int(track.tvId) else { continue }
                let season = track.nextSeason ?? 1
                group.addTask {
                    guard let detail = try? await TMDBService.season(tvId: tvId, season: season) else { return [] }
                    return (detail.episodes ?? []).compactMap { ep -> ScheduleEpisode? in
                        guard let air = ep.air_date, air.count >= 10 else { return nil }
                        guard let date = parseDay(air), date >= today, date <= end else { return nil }
                        return ScheduleEpisode(
                            tvId: tvId,
                            title: track.tvTitle ?? "Show",
                            posterPath: track.posterPath,
                            season: ep.season_number ?? season,
                            episode: ep.episode_number,
                            episodeName: ep.name,
                            airDate: air
                        )
                    }
                }
            }
            for await batch in group {
                out.append(contentsOf: batch)
            }
        }

        return out.sorted { $0.airDate < $1.airDate }
    }

    /// Next season premieres / returns for paused, finished, or caught-up shows.
    static func returningSoon(from tracks: [TrackingRecord], withinDays: Int = 45) async -> [ScheduleEpisode] {
        let today = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: withinDays, to: today) ?? today
        var out: [ScheduleEpisode] = []

        await withTaskGroup(of: ScheduleEpisode?.self) { group in
            for track in tracks.prefix(12) {
                guard let tvId = Int(track.tvId) else { continue }
                let nextSeason = (track.nextSeason ?? track.lastSeason ?? 1) + (
                    track.status == "completed" ? 1 : 0
                )
                // Prefer the season after the last watched when caught up.
                let seasonHint: Int = {
                    if let last = track.lastSeason, track.status == "completed" || track.status == "paused" {
                        return last + 1
                    }
                    return track.nextSeason ?? max(1, nextSeason)
                }()

                group.addTask {
                    // Try hinted season, then +1 if empty.
                    for season in [seasonHint, seasonHint + 1] {
                        guard let detail = try? await TMDBService.season(tvId: tvId, season: season),
                              let first = (detail.episodes ?? []).first(where: { ($0.air_date ?? "").count >= 10 }),
                              let air = first.air_date,
                              let date = parseDay(air),
                              date >= today, date <= end
                        else { continue }
                        return ScheduleEpisode(
                            tvId: tvId,
                            title: track.tvTitle ?? "Show",
                            posterPath: track.posterPath,
                            season: first.season_number ?? season,
                            episode: first.episode_number,
                            episodeName: first.name,
                            airDate: air
                        )
                    }
                    return nil
                }
            }
            for await item in group {
                if let item { out.append(item) }
            }
        }

        return out.sorted { $0.airDate < $1.airDate }
    }

    private static func parseDay(_ raw: String) -> Date? {
        let parts = raw.split(separator: "-")
        guard parts.count >= 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        return Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
    }
}
