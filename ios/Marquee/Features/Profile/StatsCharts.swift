import Charts
import SwiftUI

enum StatsFormat {
    static func minutes(_ mins: Int) -> String {
        if mins >= 24 * 60 { return span(mins) }
        return compact(mins)
    }

    /// Integer calendar pieces: `5 mo 16d 16h`. Never a decimal like 5.9 months.
    static func span(_ mins: Int) -> String {
        if mins <= 0 { return "—" }
        let hours = mins / 60
        if hours < 24 { return compact(mins) }

        let years = hours / (24 * 365)
        var leftover = hours % (24 * 365)
        let months = leftover / (24 * 30)
        leftover %= 24 * 30
        let days = leftover / 24
        let remHours = leftover % 24

        var parts: [String] = []
        if years > 0 { parts.append("\(years)y") }
        if months > 0 { parts.append("\(months) mo") }
        if days > 0 { parts.append("\(days)d") }
        if remHours > 0 { parts.append("\(remHours)h") }
        return parts.isEmpty ? compact(mins) : parts.joined(separator: " ")
    }

    private static func compact(_ mins: Int) -> String {
        if mins <= 0 { return "—" }
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    static func monthLabel(_ raw: String?) -> String {
        guard let raw, raw.count >= 7 else { return raw ?? "" }
        let year = Int(raw.prefix(4)) ?? 0
        let month = Int(raw.dropFirst(5).prefix(2)) ?? 0
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let date = Calendar.current.date(from: comps) else { return raw }
        return date.formatted(.dateTime.month(.abbreviated))
    }

    static func weekdayIndex(for dateKey: String) -> Int? {
        let parts = dateKey.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        guard let date = Calendar.current.date(from: comps) else { return nil }
        let weekday = Calendar.current.component(.weekday, from: date)
        return (weekday + 5) % 7
    }
}

struct DecadeMeterList: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let decades: [TasteDecade]
    var tint: Color

    var body: some View {
        let rows = decades.filter { ($0.count ?? 0) > 0 }
        let maxValue = max(rows.map { $0.count ?? 0 }.max() ?? 1, 1)
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(MarqueeType.labelTracking)
                .textCase(.uppercase)
                .foregroundStyle(theme.inkMuted)
                .padding(.top, 4)
            ForEach(rows) { decade in
                HStack(spacing: 10) {
                    Text(decade.decade ?? "")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.ink)
                        .frame(width: 52, alignment: .leading)
                    GeometryReader { geo in
                        Capsule()
                            .fill(tint.opacity(0.14))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(tint)
                                    .frame(width: geo.size.width * CGFloat(decade.count ?? 0) / CGFloat(maxValue))
                            }
                    }
                    .frame(height: 8)
                    Text("\(decade.count ?? 0)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }
}

struct GenreMeterList: View {
    @Environment(\.marqueeTheme) private var theme
    let items: [TasteGenre]
    var tint: Color

    var body: some View {
        let rows = Array(items.prefix(6))
        let maxValue = max(rows.map(\.amount).max() ?? 1, 1)
        VStack(spacing: 10) {
            ForEach(rows) { genre in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(genre.name ?? "Genre")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                        Spacer()
                        if let pct = genre.pct, pct > 0 {
                            Text("\(pct)%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(tint)
                                .monospacedDigit()
                        } else {
                            Text("\(genre.amount)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(tint)
                                .monospacedDigit()
                        }
                    }
                    GeometryReader { geo in
                        Capsule()
                            .fill(tint.opacity(0.14))
                            .overlay(alignment: .leading) {
                                Capsule()
                                    .fill(tint)
                                    .frame(width: geo.size.width * CGFloat(genre.amount) / CGFloat(maxValue))
                            }
                    }
                    .frame(height: 6)
                }
            }
        }
    }
}
