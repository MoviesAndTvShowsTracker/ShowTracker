import Charts
import SwiftUI

// MARK: - Chapter header

/// Big section break: icon chip + title + one-line summary.
struct StatsChapterHeader: View {
    @Environment(\.marqueeTheme) private var theme
    let icon: String
    let title: String
    let summary: String?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(theme.olive)
                .frame(width: 40, height: 40)
                .background(theme.oliveSoft, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.ink)
                if let summary {
                    Text(summary)
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Fact grid

struct StatsFact: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    var unit: String? = nil
}

/// A spec sheet: four figures in one card, hairline dividers between.
struct FactGrid: View {
    @Environment(\.marqueeTheme) private var theme
    let facts: [StatsFact]

    var body: some View {
        let rows = stride(from: 0, to: facts.count, by: 2).map { Array(facts[$0..<min($0 + 2, facts.count)]) }
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { i, fact in
                        cell(fact)
                        if i == 0 && row.count > 1 {
                            Rectangle().fill(theme.border).frame(width: 1)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                if index < rows.count - 1 {
                    Rectangle().fill(theme.border).frame(height: 1)
                }
            }
        }
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    private func cell(_ fact: StatsFact) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(fact.label)
                .font(.caption2.weight(.bold))
                .tracking(MarqueeType.labelTracking)
                .textCase(.uppercase)
                .foregroundStyle(theme.inkMuted)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(fact.value)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if let unit = fact.unit {
                    Text(unit)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.inkMuted)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Show progress (one stacked bar)

struct ShowProgressBar: View {
    @Environment(\.marqueeTheme) private var theme
    let library: StatsLibrary
    @State private var grown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var segments: [(String, Int, Double)] {
        [
            ("Finished", library.finished ?? 0, 1.0),
            ("Watching", library.watching ?? 0, 0.6),
            ("Caught up", library.caughtUp ?? 0, 0.38),
            ("Paused", library.pausedCount, 0.18),
        ].filter { $0.1 > 0 }
    }

    var body: some View {
        let total = max(segments.reduce(0) { $0 + $1.1 }, 1)
        NavigationLink {
            TVLibraryView()
        } label: {
            GlassCard(padding: 18) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionKicker(text: "Your shows")
                            Text("\(library.completionRate ?? 0)% finished")
                                .font(.headline)
                                .foregroundStyle(theme.ink)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.inkMuted.opacity(0.6))
                    }
                    GeometryReader { geo in
                        HStack(spacing: 3) {
                            ForEach(segments, id: \.0) { seg in
                                Capsule(style: .continuous)
                                    .fill(theme.olive.opacity(seg.2))
                                    .frame(width: max(6, (geo.size.width - CGFloat(segments.count - 1) * 3) * CGFloat(seg.1) / CGFloat(total)))
                            }
                        }
                        .frame(width: geo.size.width, alignment: .leading)
                        .scaleEffect(x: grown || reduceMotion ? 1 : 0.02, anchor: .leading)
                    }
                    .frame(height: 12)
                    LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], spacing: 8) {
                        ForEach(segments, id: \.0) { seg in
                            HStack(spacing: 6) {
                                Circle().fill(theme.olive.opacity(seg.2)).frame(width: 8, height: 8)
                                Text(seg.0).foregroundStyle(theme.inkMuted)
                                Text("\(seg.1)").fontWeight(.semibold).foregroundStyle(theme.ink).monospacedDigit()
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
        .buttonStyle(PressableRowStyle())
        .onAppear {
            withAnimation(MarqueeMotion.reveal.delay(0.1)) { grown = true }
        }
    }
}

// MARK: - Top-rated poster rail

struct RatedPosterRail: View {
    @Environment(\.marqueeTheme) private var theme
    let kicker: String
    let title: String
    let items: [StatsRatedTitle]
    let isTV: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(kicker: kicker, title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        NavigationLink {
                            destination(item)
                        } label: {
                            tile(item, rank: index + 1)
                        }
                        .buttonStyle(PressableRowStyle())
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .padding(.horizontal, -20)
        }
    }

    @ViewBuilder
    private func destination(_ item: StatsRatedTitle) -> some View {
        if isTV, let id = Int(item.tvId ?? "") {
            TVDetailView(tvId: id)
        } else if let id = Int(item.movieId ?? "") {
            MovieDetailView(movieId: id)
        }
    }

    private func tile(_ item: StatsRatedTitle, rank: Int) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath, size: "w342"))
                .frame(width: 112, height: 168)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(theme.border, lineWidth: 1))
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").imageScale(.small)
                        Text(StarFormat.string(item.rating))
                    }
                    .font(.caption2.weight(.bold).monospacedDigit())
                    .foregroundStyle(MarqueeColor.saltGrey)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(MarqueeColor.deepOlive.opacity(0.88), in: Capsule())
                    .padding(7)
                }
            Text(item.displayTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(2)
        }
        .frame(width: 112, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(rank). \(item.displayTitle), \(StarFormat.string(item.rating)) stars")
    }
}

enum StarFormat {
    static func string(_ value: Double?) -> String {
        guard let value else { return "—" }
        return value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Rating histogram

struct RatingHistogram: View {
    @Environment(\.marqueeTheme) private var theme
    let buckets: [StatsRatingBucket]
    let average: Double?
    let count: Int?

    @State private var selected: Double?

    private var mode: StatsRatingBucket? { buckets.max { ($0.count ?? 0) < ($1.count ?? 0) } }
    private var focus: StatsRatingBucket? { buckets.first { $0.stars == selected } }

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionKicker(text: "How you rate")
                        Text(headline)
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                            .contentTransition(.numericText())
                            .animation(MarqueeMotion.micro, value: selected)
                    }
                    Spacer()
                    if let average, average > 0 {
                        VStack(alignment: .trailing, spacing: 0) {
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill").imageScale(.small)
                                Text(String(format: "%.1f", average))
                            }
                            .font(.title3.weight(.bold).monospacedDigit())
                            .foregroundStyle(theme.ink)
                            Text("average")
                                .font(.caption2)
                                .foregroundStyle(theme.inkMuted)
                        }
                    }
                }
                Chart(buckets) { bucket in
                    BarMark(
                        x: .value("Stars", bucket.stars ?? 0),
                        y: .value("Films", bucket.count ?? 0),
                        width: .fixed(18)
                    )
                    .foregroundStyle(theme.olive.opacity(barOpacity(bucket)))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .chartXScale(domain: 0.25...5.25)
                .chartXAxis {
                    AxisMarks(values: [1.0, 2.0, 3.0, 4.0, 5.0]) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(String(repeating: "★", count: Int(v)))
                                    .font(.system(size: 8))
                                    .foregroundStyle(theme.inkMuted)
                            }
                        }
                    }
                }
                .chartYAxis(.hidden)
                .chartXSelection(value: Binding(
                    get: { selected },
                    set: { selected = $0.map { ($0 * 2).rounded() / 2 } }
                ))
                .frame(height: 110)
                .sensoryFeedback(.selection, trigger: selected)
            }
        }
    }

    private var headline: String {
        if let focus {
            let n = focus.count ?? 0
            return "\(StarFormat.string(focus.stars)) stars · \(n) \(n == 1 ? "title" : "titles")"
        }
        if let mode, let stars = mode.stars, (mode.count ?? 0) > 0 {
            return "Mostly \(StarFormat.string(stars))-star nights · \(count ?? 0) rated"
        }
        return "Nothing rated yet"
    }

    private func barOpacity(_ bucket: StatsRatingBucket) -> Double {
        if let selected { return bucket.stars == selected ? 1 : 0.3 }
        return bucket.stars == mode?.stars ? 1 : 0.55
    }
}

// MARK: - Genre stack (films)

/// One ribbon split by genre share, with a ranked legend beneath.
struct GenreStack: View {
    @Environment(\.marqueeTheme) private var theme
    let kicker: String
    let genres: [TasteGenre]

    private var top: [TasteGenre] { Array(genres.prefix(5)) }
    private let shades: [Double] = [1.0, 0.72, 0.5, 0.32, 0.18]

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionKicker(text: kicker)
                    Text(top.first?.name.map { "Mostly \($0)" } ?? "Genres")
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                }
                GeometryReader { geo in
                    let total = max(top.reduce(0) { $0 + max($1.pct ?? 0, 1) }, 1)
                    HStack(spacing: 2) {
                        ForEach(Array(top.enumerated()), id: \.element.id) { i, g in
                            Rectangle()
                                .fill(theme.olive.opacity(shades[i]))
                                .frame(width: max(4, (geo.size.width - CGFloat(top.count - 1) * 2) * CGFloat(max(g.pct ?? 0, 1)) / CGFloat(total)))
                        }
                    }
                    .clipShape(Capsule(style: .continuous))
                }
                .frame(height: 14)
                VStack(spacing: 8) {
                    ForEach(Array(top.enumerated()), id: \.element.id) { i, g in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(theme.olive.opacity(shades[i]))
                                .frame(width: 12, height: 12)
                            Text(g.name ?? "")
                                .font(.subheadline)
                                .foregroundStyle(theme.ink)
                            Spacer()
                            Text("\(g.pct ?? 0)%")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(theme.inkMuted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

// MARK: - Double feature (longest vs shortest film)

struct DoubleFeature: View {
    @Environment(\.marqueeTheme) private var theme
    let longest: StatsFilmExtreme?
    let shortest: StatsFilmExtreme?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(kicker: "Double feature", title: "Your longest and shortest sits")
            HStack(spacing: 10) {
                if let longest { tile("Longest", longest, icon: "hourglass.bottomhalf.filled") }
                if let shortest { tile("Shortest", shortest, icon: "hourglass.tophalf.filled") }
            }
        }
    }

    private func tile(_ label: String, _ film: StatsFilmExtreme, icon: String) -> some View {
        let content = VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: icon)
                .font(.caption2.weight(.bold))
                .tracking(MarqueeType.labelTracking)
                .textCase(.uppercase)
                .foregroundStyle(theme.inkMuted)
            Text(StatsFormat.minutes(film.minutes ?? 0))
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(theme.ink)
            Text(film.movieTitle ?? "Film")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(theme.inkMuted)
                .lineLimit(2, reservesSpace: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TicketStubShape(radius: 18, notch: 7).fill(theme.surfaceElevated))
        .overlay(TicketStubShape(radius: 18, notch: 7).stroke(theme.border, lineWidth: 1))

        return Group {
            if let id = Int(film.movieId ?? "") {
                NavigationLink { MovieDetailView(movieId: id) } label: { content }
                    .buttonStyle(PressableRowStyle())
            } else {
                content
            }
        }
    }
}

// MARK: - Weekday chart

struct WeekdayBars: View {
    @Environment(\.marqueeTheme) private var theme
    let days: [StatsWeekdayBucket]
    @State private var selected: String?

    private var peak: StatsWeekdayBucket? { days.max { $0.totalMins < $1.totalMins } }
    private var focus: StatsWeekdayBucket? { days.first { $0.label == selected } ?? peak }

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionKicker(text: "When you watch")
                    Text(headline)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .contentTransition(.numericText())
                        .animation(MarqueeMotion.micro, value: selected)
                }
                Chart(days) { day in
                    BarMark(x: .value("Day", day.label ?? ""), y: .value("TV", day.tvMins ?? 0), width: .ratio(0.55))
                        .foregroundStyle(by: .value("Kind", "TV"))
                        .opacity(opacity(day))
                    BarMark(x: .value("Day", day.label ?? ""), y: .value("Films", day.filmMins ?? 0), width: .ratio(0.55))
                        .foregroundStyle(by: .value("Kind", "Films"))
                        .opacity(opacity(day))
                        .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 4, topTrailing: 4)))
                }
                .chartForegroundStyleScale(["TV": theme.olive, "Films": theme.olive.opacity(0.4)])
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let s = value.as(String.self) {
                                Text(s)
                                    .font(.caption2.weight(s == focus?.label ? .bold : .medium))
                                    .foregroundStyle(s == focus?.label ? theme.ink : theme.inkMuted)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selected)
                .frame(height: 130)
                .sensoryFeedback(.selection, trigger: selected)
            }
        }
    }

    private var headline: String {
        guard let focus, focus.totalMins > 0 else { return "Every night's open" }
        let avg = (focus.days ?? 0) > 0 ? focus.totalMins / max(focus.days ?? 1, 1) : 0
        let name = Self.fullName(focus.label)
        if selected == nil {
            return "\(name)s are your big night"
        }
        return "\(name)s · \(StatsFormat.minutes(avg)) on an average night"
    }

    private func opacity(_ day: StatsWeekdayBucket) -> Double {
        guard let focusLabel = focus?.label else { return 1 }
        return day.label == focusLabel ? 1 : 0.4
    }

    static func fullName(_ short: String?) -> String {
        switch short {
        case "Mon": "Monday"
        case "Tue": "Tuesday"
        case "Wed": "Wednesday"
        case "Thu": "Thursday"
        case "Fri": "Friday"
        case "Sat": "Saturday"
        case "Sun": "Sunday"
        default: short ?? ""
        }
    }
}
