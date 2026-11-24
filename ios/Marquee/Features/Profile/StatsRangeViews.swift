import Charts
import SwiftUI

// MARK: - Compact range switch (inside the Lately card)

struct StatsRangeSwitch: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.colorScheme) private var scheme
    @Binding var selection: StatsRangeKey
    var options: [StatsRangeKey] = [.week, .month, .year]
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { key in
                let selected = key == selection
                Button {
                    guard key != selection else { return }
                    withAnimation(MarqueeMotion.standard) { selection = key }
                } label: {
                    Text(key.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected ? MarqueeColor.saltGrey : theme.inkMuted)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
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
        .padding(3)
        .background(theme.oliveSoft, in: Capsule(style: .continuous))
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Range")
    }
}

// MARK: - Screen time hero (all time)

/// The sign over the door: Deep Olive panel, a bulb row that chases once on reveal.
struct ScreenTimeHero: View {
    @ScaledMetric(relativeTo: .largeTitle) private var heroFigure: CGFloat = 50
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let overview: StatsOverview?
    let since: String?

    @State private var lit = 0
    @State private var shown = false
    private let bulbCount = 18

    private var ink: Color { MarqueeColor.saltGrey }
    private var panel: Color { scheme == .dark ? MarqueeColor.surfaceElevatedDark : MarqueeColor.deepOlive }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            bulbs

            VStack(alignment: .leading, spacing: 4) {
                Text(since.map { "Screen time · since \($0)" } ?? "Screen time")
                    .font(.caption.weight(.bold))
                    .tracking(MarqueeType.labelTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(ink.opacity(0.7))
                Text(StatsFormat.span(shown ? (overview?.totalMins ?? 0) : 0))
                    .font(.system(size: heroFigure, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.55)
                    .lineLimit(1)
                Text(hoursLine)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(ink.opacity(0.75))
            }

            HStack(alignment: .top, spacing: 0) {
                column(
                    icon: "tv",
                    title: "TV",
                    time: overview?.tvMins ?? 0,
                    detail: countLine(overview?.episodeCount, "episode", overview?.tvShowCount, "show")
                )
                Rectangle().fill(ink.opacity(0.14)).frame(width: 1).padding(.horizontal, 14)
                column(
                    icon: "film",
                    title: "Films",
                    time: overview?.filmMins ?? 0,
                    detail: countLine(overview?.filmCount, "film", nil, "")
                )
            }
            .fixedSize(horizontal: false, vertical: true)

            SplitRule(tvMins: overview?.tvMins ?? 0, filmMins: overview?.filmMins ?? 0, ink: ink)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(panel)
                .overlay(alignment: .topTrailing) {
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
        .task { await reveal() }
    }

    private var hoursLine: String {
        let hours = (overview?.totalMins ?? 0) / 60
        guard hours > 0 else { return "Your diary starts with the first mark." }
        return "\(hours.formatted()) hours in the dark"
    }

    private func countLine(_ a: Int?, _ aUnit: String, _ b: Int?, _ bUnit: String) -> String {
        var parts: [String] = []
        if let a, a > 0 { parts.append("\(a.formatted()) \(aUnit)\(a == 1 ? "" : "s")") }
        if let b, b > 0 { parts.append("\(b.formatted()) \(bUnit)\(b == 1 ? "" : "s")") }
        return parts.isEmpty ? "Nothing yet" : parts.joined(separator: " · ")
    }

    private func column(icon: String, title: String, time: Int, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(ink.opacity(0.7))
            Text(time > 0 ? StatsFormat.span(time) : "—")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail)
                .font(.caption)
                .foregroundStyle(ink.opacity(0.65))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    /// Bulbs chase on, then the total rolls up — once per appearance.
    private func reveal() async {
        if reduceMotion {
            lit = bulbCount
            shown = true
            return
        }
        guard lit == 0 else { return }
        for i in 1...bulbCount {
            try? await Task.sleep(for: .milliseconds(26))
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.18)) { lit = i }
            if i == bulbCount / 2 {
                withAnimation(.smooth(duration: 0.6)) { shown = true }
            }
        }
    }
}

// MARK: - Screen time strip (You tab)

/// Compact Deep Olive glance at total time: TV and films side by side.
struct ScreenTimeStrip: View {
    @Environment(\.colorScheme) private var scheme
    let overview: StatsOverview?

    private var ink: Color { MarqueeColor.saltGrey }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Screen time")
                    .font(.caption.weight(.bold))
                    .tracking(MarqueeType.labelTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(ink.opacity(0.7))
                Spacer()
                HStack(spacing: 4) {
                    Text("Stats")
                    Image(systemName: "chevron.right")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(ink.opacity(0.8))
            }
            HStack(alignment: .top, spacing: 0) {
                cell(icon: "tv", time: overview?.tvMins ?? 0, detail: count(overview?.episodeCount, "episode"))
                Rectangle().fill(ink.opacity(0.14)).frame(width: 1).padding(.horizontal, 14)
                cell(icon: "film", time: overview?.filmMins ?? 0, detail: count(overview?.filmCount, "film"))
            }
            .fixedSize(horizontal: false, vertical: true)
            SplitRule(tvMins: overview?.tvMins ?? 0, filmMins: overview?.filmMins ?? 0, ink: ink)
        }
        .padding(16)
        .background(
            scheme == .dark ? MarqueeColor.surfaceElevatedDark : MarqueeColor.deepOlive,
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Screen time. TV \(StatsFormat.span(overview?.tvMins ?? 0)), films \(StatsFormat.span(overview?.filmMins ?? 0))")
    }

    private func count(_ n: Int?, _ unit: String) -> String {
        let n = n ?? 0
        return "\(n.formatted()) \(unit)\(n == 1 ? "" : "s")"
    }

    private func cell(icon: String, time: Int, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ink.opacity(0.7))
                Text(time > 0 ? StatsFormat.span(time) : "—")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(ink.opacity(0.65))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// TV vs film split — two inks, no accent.
struct SplitRule: View {
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
            VStack(alignment: .leading, spacing: 6) {
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
                    Text("TV \(Int((tvFraction * 100).rounded()))%")
                    Spacer()
                    Text("Films \(100 - Int((tvFraction * 100).rounded()))%")
                }
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(ink.opacity(0.65))
            }
        }
    }
}

// MARK: - Lately (range card)

struct LatelyCard: View {
    @ScaledMetric(relativeTo: .largeTitle) private var latelyFigure: CGFloat = 34
    @Environment(\.marqueeTheme) private var theme
    let ranges: StatsRanges
    @Binding var rangeKey: StatsRangeKey

    private var range: StatsRange? { ranges[rangeKey] }
    private var totals: StatsRangeTotals? { range?.totals }

    var body: some View {
        GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    SectionKicker(text: "Lately")
                    Spacer()
                    StatsRangeSwitch(selection: $rangeKey)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(range?.isQuiet == false ? StatsFormat.span(totals?.totalMins ?? 0) : "0m")
                        .font(.system(size: latelyFigure, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.ink)
                        .contentTransition(.numericText())
                    Text(subline)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(deltaColor)
                        .contentTransition(.opacity)
                }
                .animation(MarqueeMotion.standard, value: rangeKey)

                if let trend = range?.trend, !(trend.buckets ?? []).isEmpty {
                    RunChart(trend: trend)
                        .id(rangeKey)
                        .transition(.opacity)
                }

                HStack(spacing: 14) {
                    pill("\(totals?.episodePlays ?? 0)", "episodes")
                    pill("\(totals?.filmPlays ?? 0)", "films")
                    pill("\(totals?.activeDays ?? 0)", "days")
                    Spacer(minLength: 0)
                }
                .animation(MarqueeMotion.standard, value: rangeKey)
            }
        }
    }

    private var delta: Int? {
        guard let range, !range.isQuiet, let prev = range.previous?.totalMins, prev > 0 else { return nil }
        return (totals?.totalMins ?? 0) - prev
    }

    private var deltaColor: Color {
        guard let delta, abs(delta) >= 15 else { return theme.inkMuted }
        return delta > 0 ? theme.olive : theme.inkMuted
    }

    private var subline: String {
        guard let range else { return "" }
        let when = StatsDates.rangeLine(rangeKey, start: range.start, end: range.end) ?? rangeKey.heroKicker
        if range.isQuiet { return "\(when) · \(rangeKey.quietLine)" }
        guard let delta else { return when }
        if abs(delta) < 15 { return "\(when) · level with \(rangeKey.previousPhrase)" }
        let arrow = delta > 0 ? "↑" : "↓"
        return "\(when) · \(arrow) \(StatsFormat.minutes(abs(delta))) vs \(rangeKey.previousPhrase)"
    }

    private func pill(_ value: String, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(theme.ink)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.inkMuted)
        }
    }
}

// MARK: - Run chart (scrubbable)

struct RunChart: View {
    @Environment(\.marqueeTheme) private var theme
    let trend: StatsRangeTrend

    @State private var selectedKey: String?

    private var buckets: [StatsRangeBucket] { trend.buckets ?? [] }
    private var selected: StatsRangeBucket? { buckets.first { $0.key == selectedKey } }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(readout)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(theme.inkMuted)
                .contentTransition(.numericText())
                .animation(MarqueeMotion.micro, value: selectedKey)

            Chart(buckets) { bucket in
                BarMark(
                    x: .value("When", bucket.id),
                    y: .value("Minutes", bucket.tvMins ?? 0),
                    width: .ratio(barRatio)
                )
                .foregroundStyle(tvColor(bucket))
                .opacity(opacity(for: bucket))
                .clipShape(UnevenRoundedRectangle(cornerRadii: .init(bottomLeading: 3, bottomTrailing: 3)))

                BarMark(
                    x: .value("When", bucket.id),
                    y: .value("Minutes", bucket.filmMins ?? 0),
                    width: .ratio(barRatio)
                )
                .foregroundStyle(filmColor(bucket))
                .opacity(opacity(for: bucket))
                .clipShape(UnevenRoundedRectangle(cornerRadii: .init(topLeading: 3, topTrailing: 3)))
            }
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
            .frame(height: 120)
            .sensoryFeedback(.selection, trigger: selectedKey)
            .accessibilityLabel("Watch time by \(trend.unit ?? "period")")
        }
    }

    private var barRatio: Double { buckets.count > 14 ? 0.62 : 0.5 }

    private var readout: String {
        guard let selected else { return "Drag across the bars" }
        let when = longLabel(selected)
        return selected.totalMins > 0 ? "\(when) · \(StatsFormat.minutes(selected.totalMins))" : "\(when) · nothing logged"
    }

    /// The bar to look at: the one you're touching, else the busiest.
    private var highlightKey: String? {
        if let selectedKey { return selectedKey }
        let peak = buckets.max { $0.totalMins < $1.totalMins }
        return (peak?.totalMins ?? 0) > 0 ? peak?.key : nil
    }

    private func tvColor(_ bucket: StatsRangeBucket) -> Color {
        bucket.key == highlightKey ? theme.accent : theme.olive
    }

    private func filmColor(_ bucket: StatsRangeBucket) -> Color {
        bucket.key == highlightKey ? theme.accent.opacity(0.45) : theme.olive.opacity(0.4)
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
                    .tracking(MarqueeType.labelTracking)
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
    @State private var expanded = false

    private var maxPlays: Int { max(shows.map { $0.plays ?? 0 }.max() ?? 1, 1) }
    private var visible: [StatsTopShow] { expanded ? shows : Array(shows.prefix(5)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StatsSectionHeader(kicker: "Most watched", title: "Top billing")
            VStack(spacing: 0) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, show in
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
                    if index < visible.count - 1 {
                        Rectangle().fill(theme.border).frame(height: 1).padding(.leading, 86)
                    }
                }
                if shows.count > 5 {
                    Rectangle().fill(theme.border).frame(height: 1)
                    Button {
                        withAnimation(MarqueeMotion.standard) { expanded.toggle() }
                    } label: {
                        HStack(spacing: 6) {
                            Text(expanded ? "Show fewer" : "Show all \(shows.count)")
                            Image(systemName: "chevron.down")
                                .rotationEffect(.degrees(expanded ? 180 : 0))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.olive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableRowStyle())
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
                .font(.system(.title3).weight(.bold).monospacedDigit())
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
                Text("\(show.plays ?? 0) episodes · \(StatsFormat.minutes(show.mins ?? 0))")
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
            StatsSectionHeader(kicker: "Recently watched", title: "Last on the marquee")
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
                    Image(systemName: "star.fill").imageScale(.small).foregroundStyle(theme.accent)
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
