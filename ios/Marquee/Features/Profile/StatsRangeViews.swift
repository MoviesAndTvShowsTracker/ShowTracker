import Charts
import SwiftUI

// MARK: - Range switch (glass chrome)

struct StatsRangeSwitch: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Binding var selection: StatsRangeKey
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(StatsRangeKey.allCases) { key in
                let selected = key == selection
                Button {
                    guard key != selection else { return }
                    withAnimation(MarqueeMotion.standard) { selection = key }
                } label: {
                    Text(key.title)
                        .font(.subheadline.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? MarqueeColor.saltGrey : theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selected {
                                Capsule(style: .continuous)
                                    .fill(scheme == .dark ? MarqueeColor.oliveLeaf : MarqueeColor.deepOlive)
                                    .matchedGeometryEffect(id: "rangePill", in: pill)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .glassEffect(.regular.interactive(), in: .capsule)
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Stats range")
    }
}

// MARK: - Marquee hero

/// The sign over the door: Deep Olive panel, a bulb row that chases once on reveal.
struct MarqueeHero: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let rangeKey: StatsRangeKey
    let range: StatsRange?
    let dateLine: String?

    @State private var lit = 0
    private let bulbCount = 18

    private var totals: StatsRangeTotals? { range?.totals }
    private var ink: Color { MarqueeColor.saltGrey }
    private var panel: Color { scheme == .dark ? MarqueeColor.surfaceElevatedDark : MarqueeColor.deepOlive }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            bulbs

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(rangeKey.heroKicker)
                    if let dateLine {
                        Text("·")
                        Text(dateLine)
                    }
                }
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(ink.opacity(0.7))

                Text(range?.isQuiet == false ? StatsFormat.span(totals?.totalMins ?? 0) : "0m")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(subline)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ink.opacity(0.78))
                    .contentTransition(.opacity)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 0) {
                figure("Episodes", totals?.episodePlays ?? 0)
                divider
                figure("Films", totals?.filmPlays ?? 0)
                divider
                figure("Shows", totals?.showCount ?? 0)
                divider
                figure("Days", totals?.activeDays ?? 0)
            }

            SplitRule(tvMins: totals?.tvMins ?? 0, filmMins: totals?.filmMins ?? 0, ink: ink)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(panel)
                .overlay(alignment: .topTrailing) {
                    // Soft house-light falloff — depth without a gradient wash.
                    Circle()
                        .fill(MarqueeColor.saltGrey.opacity(scheme == .dark ? 0.05 : 0.08))
                        .frame(width: 260, height: 260)
                        .blur(radius: 60)
                        .offset(x: 80, y: -120)
                }
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(MarqueeColor.saltGrey.opacity(scheme == .dark ? 0.1 : 0), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .task(id: rangeKey) { await chase() }
    }

    private var subline: String {
        guard let range, !range.isQuiet else { return rangeKey.quietLine }
        if rangeKey == .all {
            let days = totals?.activeDays ?? 0
            return days > 0 ? "Across \(days) diary days." : "Your whole diary."
        }
        guard let prev = range.previous?.totalMins else { return "" }
        let now = totals?.totalMins ?? 0
        if prev <= 0 { return "Nothing logged by \(rangeKey.previousPhrase). Fresh run." }
        let delta = now - prev
        if abs(delta) < 15 { return "Level with \(rangeKey.previousPhrase)." }
        let arrow = delta > 0 ? "↑" : "↓"
        return "\(arrow) \(StatsFormat.minutes(abs(delta))) vs \(rangeKey.previousPhrase)"
    }

    private var bulbs: some View {
        HStack(spacing: 0) {
            ForEach(0..<bulbCount, id: \.self) { i in
                let on = i < lit
                Circle()
                    .fill(on ? MarqueeColor.saltGrey : MarqueeColor.saltGrey.opacity(0.18))
                    .frame(width: 5, height: 5)
                    .shadow(color: on ? MarqueeColor.saltGrey.opacity(0.7) : .clear, radius: on ? 3 : 0)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func chase() async {
        if reduceMotion {
            lit = bulbCount
            return
        }
        lit = 0
        for i in 1...bulbCount {
            try? await Task.sleep(for: .milliseconds(28))
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.18)) { lit = i }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(ink.opacity(0.14))
            .frame(width: 1, height: 28)
    }

    private func figure(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 3) {
            Text("\(value)")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(ink)
                .contentTransition(.numericText(value: Double(value)))
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ink.opacity(0.62))
        }
        .frame(maxWidth: .infinity)
    }
}

/// TV vs film split on the hero — two inks, no accent.
private struct SplitRule: View {
    let tvMins: Int
    let filmMins: Int
    let ink: Color

    private var tvFraction: CGFloat {
        let total = tvMins + filmMins
        guard total > 0 else { return 0.5 }
        return CGFloat(tvMins) / CGFloat(total)
    }

    var body: some View {
        if tvMins + filmMins > 0 {
            VStack(alignment: .leading, spacing: 7) {
                GeometryReader { geo in
                    HStack(spacing: 3) {
                        if tvMins > 0 {
                            Capsule().fill(ink)
                                .frame(width: filmMins > 0 ? max(6, (geo.size.width - 3) * tvFraction) : geo.size.width)
                        }
                        if filmMins > 0 {
                            Capsule().fill(ink.opacity(0.35))
                        }
                    }
                }
                .frame(height: 6)
                HStack {
                    Label("TV \(StatsFormat.minutes(tvMins))", systemImage: "tv")
                    Spacer()
                    Label("Films \(StatsFormat.minutes(filmMins))", systemImage: "film")
                }
                .font(.caption2.weight(.semibold))
                .foregroundStyle(ink.opacity(0.7))
                .labelStyle(SplitLabelStyle())
                .contentTransition(.numericText())
            }
        }
    }
}

private struct SplitLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon.imageScale(.small)
            configuration.title
        }
    }
}

// MARK: - The run (trend chart with scrub)

struct RunChart: View {
    @Environment(\.marqueeTheme) private var theme
    let rangeKey: StatsRangeKey
    let trend: StatsRangeTrend

    @State private var selectedKey: String?

    private var buckets: [StatsRangeBucket] { trend.buckets ?? [] }
    private var selected: StatsRangeBucket? { buckets.first { $0.key == selectedKey } }
    private var peak: StatsRangeBucket? { buckets.max { $0.totalMins < $1.totalMins } }

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        SectionKicker(text: "The run")
                        Text(headline)
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                            .contentTransition(.numericText())
                            .animation(MarqueeMotion.micro, value: selectedKey)
                    }
                    Spacer()
                    legend
                }

                Chart(buckets) { bucket in
                    BarMark(
                        x: .value("When", bucket.id),
                        y: .value("Minutes", bucket.tvMins ?? 0),
                        width: .ratio(barRatio)
                    )
                    .foregroundStyle(by: .value("Kind", "TV"))
                    .opacity(opacity(for: bucket))
                    .clipShape(UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: 3, bottomTrailing: 3)))

                    BarMark(
                        x: .value("When", bucket.id),
                        y: .value("Minutes", bucket.filmMins ?? 0),
                        width: .ratio(barRatio)
                    )
                    .foregroundStyle(by: .value("Kind", "Films"))
                    .opacity(opacity(for: bucket))
                    .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 3, topTrailing: 3)))
                }
                .chartForegroundStyleScale(["TV": theme.olive, "Films": theme.olive.opacity(0.4)])
                .chartLegend(.hidden)
                .chartYAxis(.hidden)
                .chartXAxis {
                    AxisMarks(values: axisValues) { value in
                        AxisValueLabel {
                            if let id = value.as(String.self) {
                                Text(label(for: id))
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(theme.inkMuted)
                            }
                        }
                    }
                }
                .chartXSelection(value: $selectedKey)
                .frame(height: 150)
                .sensoryFeedback(.selection, trigger: selectedKey)
                .accessibilityLabel("Watch time by \(trend.unit ?? "period")")
            }
        }
    }

    private var barRatio: Double { buckets.count > 14 ? 0.62 : 0.5 }

    private var headline: String {
        if let selected {
            let when = longLabel(selected)
            return selected.totalMins > 0
                ? "\(when) · \(StatsFormat.minutes(selected.totalMins))"
                : "\(when) · dark"
        }
        if let peak, peak.totalMins > 0 {
            return "Peak \(longLabel(peak)) · \(StatsFormat.minutes(peak.totalMins))"
        }
        return "No screenings yet"
    }

    private func opacity(for bucket: StatsRangeBucket) -> Double {
        if bucket.future == true { return 0.25 }
        guard let selectedKey else { return 1 }
        return bucket.key == selectedKey ? 1 : 0.35
    }

    /// Month view has ~30 bars — label a handful so the axis stays calm.
    private var axisValues: [String] {
        let ids = buckets.map(\.id)
        guard ids.count > 12 else { return ids }
        return ids.enumerated().compactMap { i, id in
            (i == 0 || (i + 1) % 7 == 0) ? id : nil
        }
    }

    private func label(for id: String) -> String {
        buckets.first { $0.id == id }?.label ?? id
    }

    private func longLabel(_ bucket: StatsRangeBucket) -> String {
        guard let key = bucket.key else { return bucket.label ?? "" }
        switch trend.unit {
        case "day":
            guard let date = StatsDates.date(fromKey: key) else { return bucket.label ?? key }
            return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        case "month":
            return StatsFormat.monthLabel(key)
        default:
            return key
        }
    }

    private var legend: some View {
        HStack(spacing: 10) {
            dot(theme.olive, "TV")
            dot(theme.olive.opacity(0.4), "Films")
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(theme.inkMuted)
    }

    private func dot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
    }
}

// MARK: - Ticket stubs

struct TicketStubRow: View {
    @Environment(\.marqueeTheme) private var theme
    let activity: StatsActivity?
    let memberSince: String?

    var body: some View {
        HStack(spacing: 10) {
            stub(
                value: "\(activity?.streak ?? 0)",
                unit: (activity?.streak ?? 0) == 1 ? "day" : "days",
                label: "Streak",
                live: (activity?.streak ?? 0) > 0
            )
            stub(value: "\(activity?.longestStreak ?? 0)", unit: "days", label: "Best run", live: false)
            stub(value: "\(activity?.activeDays ?? 0)", unit: "nights", label: "In the diary", live: false)
        }
    }

    private func stub(value: String, unit: String, label: String, live: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                if live {
                    Circle().fill(theme.accent).frame(width: 6, height: 6)
                }
                Text(label)
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(.title2.weight(.bold).monospacedDigit())
                    .foregroundStyle(theme.ink)
                Text(unit)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TicketStubShape().fill(theme.surfaceElevated))
        .overlay(TicketStubShape().stroke(theme.border, lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

/// Rounded card with half-moon notches on both sides — a torn ticket stub.
struct TicketStubShape: Shape {
    var radius: CGFloat = 14
    var notch: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let card = Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
        var notches = Path()
        notches.addEllipse(in: CGRect(x: rect.minX - notch, y: rect.midY - notch, width: notch * 2, height: notch * 2))
        notches.addEllipse(in: CGRect(x: rect.maxX - notch, y: rect.midY - notch, width: notch * 2, height: notch * 2))
        return card.subtracting(notches)
    }
}

// MARK: - Top billing (shows)

struct TopBillingList: View {
    @Environment(\.marqueeTheme) private var theme
    let shows: [StatsTopShow]

    private var maxPlays: Int { max(shows.map { $0.plays ?? 0 }.max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(kicker: "Top billing", title: "Shows you kept coming back to")
            VStack(spacing: 0) {
                ForEach(Array(shows.enumerated()), id: \.element.id) { index, show in
                    if let tvId = Int(show.tvId?.stringValue ?? "") {
                        NavigationLink {
                            TVDetailView(tvId: tvId)
                        } label: {
                            row(index: index, show: show)
                        }
                        .buttonStyle(PressableRowStyle())
                    } else {
                        row(index: index, show: show)
                    }
                    if index < shows.count - 1 {
                        Rectangle().fill(theme.border).frame(height: 1).padding(.leading, 86)
                    }
                }
            }
            .padding(.vertical, 4)
            .background(theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(theme.border, lineWidth: 1))
        }
    }

    private func row(index: Int, show: StatsTopShow) -> some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(.title3, design: .rounded).weight(.bold).monospacedDigit())
                .foregroundStyle(index == 0 ? theme.ink : theme.inkMuted)
                .frame(width: 18)
            CachedAsyncImage(url: AppConfig.posterURL(path: show.tvPosterImage, size: "w185"))
                .frame(width: 40, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 6) {
                Text(show.tvTitle ?? "Show")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                GeometryReader { geo in
                    Capsule()
                        .fill(theme.oliveSoft)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(theme.olive)
                                .frame(width: max(6, geo.size.width * CGFloat(show.plays ?? 0) / CGFloat(maxPlays)))
                        }
                }
                .frame(height: 5)
                Text("\(show.plays ?? 0) plays · \(StatsFormat.minutes(show.mins ?? 0))")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
                    .monospacedDigit()
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.inkMuted.opacity(0.6))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}

// MARK: - On the marquee (films rail)

struct FilmsOnMarqueeRail: View {
    @Environment(\.marqueeTheme) private var theme
    let films: [StatsRangeFilm]
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(
                kicker: "On the marquee",
                title: total == 1 ? "1 film" : "\(total) films",
                trailing: nil
            )
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(films) { film in
                        if let id = Int(film.movieId ?? "") {
                            NavigationLink {
                                MovieDetailView(movieId: id)
                            } label: {
                                tile(film)
                            }
                            .buttonStyle(PressableRowStyle())
                        } else {
                            tile(film)
                        }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .padding(.horizontal, -20)
        }
    }

    private func tile(_ film: StatsRangeFilm) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            CachedAsyncImage(url: AppConfig.posterURL(path: film.poster, size: "w342"))
                .frame(width: 104, height: 156)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
            Text(film.title ?? "Film")
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
            HStack(spacing: 4) {
                if let rating = film.rating {
                    Image(systemName: "star.fill").imageScale(.small)
                    Text(String(format: "%.1f", rating))
                } else if let when = StatsDates.shortDay(film.watchedAt) {
                    Text(when)
                }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(theme.inkMuted)
        }
        .frame(width: 104, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Shared bits

struct StatsSectionHeader: View {
    @Environment(\.marqueeTheme) private var theme
    let kicker: String
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                SectionKicker(text: kicker)
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.inkMuted)
            }
        }
    }
}

struct PressableRowStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(MarqueeMotion.press, value: configuration.isPressed)
    }
}

enum StatsDates {
    static func date(fromKey key: String) -> Date? {
        let parts = key.prefix(10).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    static func shortDay(_ iso: String?) -> String? {
        guard let iso, let date = date(fromKey: iso) else { return nil }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    /// "Nov 16 – 23", "November", "2026" for the hero kicker.
    static func rangeLine(_ key: StatsRangeKey, start: String?, end: String?) -> String? {
        switch key {
        case .all:
            return nil
        case .year:
            return start.map { String($0.prefix(4)) }
        case .month:
            guard let start, let d = date(fromKey: start) else { return nil }
            return d.formatted(.dateTime.month(.wide))
        case .week:
            guard let start, let s = date(fromKey: start),
                  let e = Calendar.current.date(byAdding: .day, value: 6, to: s) else { return nil }
            let sameMonth = Calendar.current.isDate(s, equalTo: e, toGranularity: .month)
            let left = s.formatted(.dateTime.month(.abbreviated).day())
            let right = sameMonth ? e.formatted(.dateTime.day()) : e.formatted(.dateTime.month(.abbreviated).day())
            return "\(left) – \(right)"
        }
    }
}
