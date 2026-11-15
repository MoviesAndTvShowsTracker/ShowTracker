import Charts
import SwiftUI

enum StatsFormat {
    static func minutes(_ mins: Int) -> String {
        if mins <= 0 { return "—" }
        let h = mins / 60
        let m = mins % 60
        if h >= 24 {
            let d = h / 24
            let rh = h % 24
            return rh == 0 ? "\(d)d" : "\(d)d \(rh)h"
        }
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

struct WeekdayPoint: Identifiable {
    var id: String { label }
    let label: String
    let fullName: String
    let tvMins: Int
    let filmMins: Int
    var total: Int { tvMins + filmMins }
}

struct TrendPoint: Identifiable {
    let id: String
    let label: String
    let kind: String
    let minutes: Int
}

struct WeekdayRhythmChart: View {
    @Environment(\.marqueeTheme) private var theme
    let days: [WeekdayPoint]
    @State private var selected: String?

    private var picked: WeekdayPoint? {
        days.first(where: { $0.label == selected }) ?? days.max(by: { $0.total < $1.total })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionKicker(text: "Weekday rhythm", accented: true)
                Spacer()
                HStack(spacing: 10) {
                    legendDot(theme.olive, "TV")
                    legendDot(theme.accent, "Films")
                }
            }

            Chart {
                ForEach(days) { day in
                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("Minutes", day.tvMins)
                    )
                    .foregroundStyle(by: .value("Kind", "TV"))
                    BarMark(
                        x: .value("Day", day.label),
                        y: .value("Minutes", day.filmMins)
                    )
                    .foregroundStyle(by: .value("Kind", "Films"))
                }
            }
            .chartForegroundStyleScale([
                "TV": theme.olive,
                "Films": theme.accent
            ])
            .chartLegend(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(theme.border)
                    AxisValueLabel {
                        if let mins = value.as(Int.self) {
                            Text(mins >= 60 ? "\(mins / 60)h" : "\(mins)m")
                                .font(.caption2)
                                .foregroundStyle(theme.inkMuted)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(theme.inkMuted)
                        }
                    }
                }
            }
            .chartXSelection(value: $selected)
            .frame(height: 148)

            if let picked, picked.total > 0 {
                Text("\(picked.fullName)s — \(StatsFormat.minutes(picked.tvMins)) of TV, \(StatsFormat.minutes(picked.filmMins)) of films")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            } else {
                Text("Tap a day to split TV and films.")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .padding(16)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private func legendDot(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.inkMuted)
        }
    }
}

struct TwelveWeekChart: View {
    @Environment(\.marqueeTheme) private var theme
    let points: [TrendPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Last 12 weeks")
            Chart(points) { point in
                AreaMark(
                    x: .value("Week", point.label),
                    y: .value("Minutes", point.minutes),
                    series: .value("Kind", point.kind)
                )
                .foregroundStyle(by: .value("Kind", point.kind))
                .interpolationMethod(.catmullRom)
                LineMark(
                    x: .value("Week", point.label),
                    y: .value("Minutes", point.minutes),
                    series: .value("Kind", point.kind)
                )
                .foregroundStyle(by: .value("Kind", point.kind))
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.8))
            }
            .chartForegroundStyleScale([
                "TV": theme.olive.opacity(0.85),
                "Films": theme.accent.opacity(0.85)
            ])
            .chartLegend(position: .top, alignment: .trailing)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(theme.border)
                    AxisValueLabel {
                        if let mins = value.as(Int.self) {
                            Text(mins >= 60 ? "\(mins / 60)h" : "\(mins)")
                                .font(.caption2)
                                .foregroundStyle(theme.inkMuted)
                        }
                    }
                }
            }
            .frame(height: 132)
        }
        .padding(16)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}

struct DiaryHeatmap: View {
    @Environment(\.marqueeTheme) private var theme
    let days: [StatsDayBucket]
    private let weeks = 16
    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    private var cells: [[HeatCell]] {
        let byDate = Dictionary(uniqueKeysWithValues: days.compactMap { day -> (String, StatsDayBucket)? in
            guard let date = day.date else { return nil }
            return (date, day)
        })
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        let daysFromMonday = (weekday + 5) % 7
        guard let thisMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: today) else { return [] }
        guard let start = cal.date(byAdding: .weekOfYear, value: -(weeks - 1), to: thisMonday) else { return [] }

        return (0..<weeks).map { week in
            (0..<7).map { dow in
                let date = cal.date(byAdding: .day, value: week * 7 + dow, to: start) ?? today
                let key = Self.key(date)
                let bucket = byDate[key]
                return HeatCell(
                    date: key,
                    tv: bucket?.episodes ?? 0,
                    films: bucket?.films ?? 0,
                    minutes: bucket?.minutes ?? 0
                )
            }
        }
    }

    private var maxMinutes: Int {
        max(cells.flatMap { $0 }.map(\.minutes).max() ?? 1, 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                SectionKicker(text: "Diary heat")
                Spacer()
                Text("16 weeks")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.inkMuted)
            }

            GeometryReader { geo in
                let labelW: CGFloat = 12
                let gap: CGFloat = 3
                let cell = max(8, floor((geo.size.width - labelW - gap) / CGFloat(weeks) - gap))
                HStack(alignment: .top, spacing: gap) {
                    VStack(spacing: gap) {
                        ForEach(Array(labels.enumerated()), id: \.offset) { _, label in
                            Text(label)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(theme.inkMuted)
                                .frame(width: labelW, height: cell)
                        }
                    }
                    HStack(spacing: gap) {
                        ForEach(Array(cells.enumerated()), id: \.offset) { _, column in
                            VStack(spacing: gap) {
                                ForEach(column) { item in
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(fill(for: item))
                                        .frame(width: cell, height: cell)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 7 * 15)

            HStack(spacing: 8) {
                Text("Empty")
                    .font(.caption2)
                    .foregroundStyle(theme.inkMuted)
                heatmapKey
                Text("Busy")
                    .font(.caption2)
                    .foregroundStyle(theme.inkMuted)
                Spacer()
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(theme.accent).frame(width: 8, height: 8)
                    Text("Film day")
                        .font(.caption2)
                        .foregroundStyle(theme.inkMuted)
                }
            }
        }
        .padding(16)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private var heatmapKey: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.olive.opacity(0.18 + Double(i) * 0.22))
                    .frame(width: 10, height: 10)
            }
        }
    }

    private func fill(for cell: HeatCell) -> Color {
        if cell.minutes <= 0 && cell.tv == 0 && cell.films == 0 {
            return theme.border.opacity(0.7)
        }
        if cell.films > 0 && cell.tv == 0 {
            let t = min(1, Double(cell.minutes) / Double(maxMinutes))
            return theme.accent.opacity(0.35 + t * 0.55)
        }
        let t = min(1, Double(cell.minutes) / Double(maxMinutes))
        return theme.olive.opacity(0.28 + t * 0.72)
    }

    private static func key(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

private struct HeatCell: Identifiable {
    var id: String { date }
    let date: String
    let tv: Int
    let films: Int
    let minutes: Int
}

struct DecadeChart: View {
    @Environment(\.marqueeTheme) private var theme
    let decades: [TasteDecade]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Film decades")
            Chart(decades) { item in
                BarMark(
                    x: .value("Count", item.count ?? 0),
                    y: .value("Decade", item.decade ?? "")
                )
                .foregroundStyle(theme.accent)
                .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) { _ in
                    AxisGridLine().foregroundStyle(theme.border)
                    AxisValueLabel()
                        .font(.caption2)
                        .foregroundStyle(theme.inkMuted)
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.ink)
                        }
                    }
                }
            }
            .frame(height: max(120, CGFloat(decades.count) * 28))
        }
        .padding(16)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
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
