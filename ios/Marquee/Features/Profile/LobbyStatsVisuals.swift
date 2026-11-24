import SwiftUI

/// The single day you watched the most, grouped one tile per title.
struct BiggestNightStrip: View {
    @Environment(\.marqueeTheme) private var theme
    let night: StatsBiggestNight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(
                kicker: "Biggest night",
                title: night.date.map { shortDate($0) } ?? "One long night",
                trailing: (night.minutes ?? 0) > 0 ? "\(night.count ?? 0) plays · \(StatsFormat.minutes(night.minutes ?? 0))" : "\(night.count ?? 0) plays"
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: 6) {
                            CachedAsyncImage(url: AppConfig.posterURL(path: group.poster, size: "w185"))
                                .frame(width: 84, height: 126)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(alignment: .topTrailing) {
                                    if group.count > 1 {
                                        Text("×\(group.count)")
                                            .font(.caption2.weight(.bold).monospacedDigit())
                                            .foregroundStyle(MarqueeColor.saltGrey)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 3)
                                            .background(MarqueeColor.deepOlive.opacity(0.88), in: Capsule())
                                            .padding(6)
                                    }
                                }
                            Text(group.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.ink)
                                .lineLimit(2)
                            Text(group.detail)
                                .font(.caption2)
                                .foregroundStyle(theme.inkMuted)
                                .lineLimit(1)
                        }
                        .frame(width: 84, alignment: .leading)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.vertical, 2)
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .padding(.horizontal, -20)
        }
    }

    private struct NightGroup: Identifiable {
        let id: String
        let title: String
        let poster: String?
        var count: Int
        var mins: Int
        let isFilm: Bool

        var detail: String {
            let what = isFilm ? "film" : (count == 1 ? "episode" : "episodes")
            if isFilm { return mins > 0 ? StatsFormat.minutes(mins) : "Film" }
            return "\(count) \(what)"
        }
    }

    /// One tile per show or film, in the order the night unfolded.
    private var groups: [NightGroup] {
        var out: [NightGroup] = []
        var index: [String: Int] = [:]
        for item in night.items ?? [] {
            let key = "\(item.kind ?? "")-\(item.mediaId ?? item.title ?? "")"
            if let i = index[key] {
                out[i].count += 1
                out[i].mins += item.mins ?? 0
            } else {
                index[key] = out.count
                let isFilm = item.kind == "film"
                out.append(NightGroup(
                    id: key,
                    title: (isFilm ? item.title : item.subtitle ?? item.title) ?? "",
                    poster: item.stillOrPoster,
                    count: 1,
                    mins: item.mins ?? 0,
                    isFilm: isFilm
                ))
            }
        }
        return out
    }

    private func shortDate(_ iso: String) -> String {
        guard iso.count >= 10 else { return iso }
        let day = String(iso.prefix(10))
        let parts = day.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              let date = Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
        else { return iso }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }
}
