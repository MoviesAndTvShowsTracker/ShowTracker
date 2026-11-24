import SwiftUI

private struct StatsCard<Content: View>: View {
    @Environment(\.marqueeTheme) private var theme
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(theme.border, lineWidth: 1))
    }
}

// MARK: - Viewer type

/// The server's read on how you watch: a name, a line, and the four traits behind it.
struct ViewerTypeCard: View {
    @Environment(\.marqueeTheme) private var theme
    let type: StatsLobbyType

    private var traits: [String] {
        [type.scheduleLabel, type.passLabel, type.finishLabel, type.mediaLabel].compactMap { $0 }.filter { !$0.isEmpty }
    }

    var body: some View {
        StatsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "theatermasks.fill")
                        .font(.title3)
                        .foregroundStyle(theme.olive)
                        .frame(width: 44, height: 44)
                        .background(theme.oliveSoft, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("You watch like")
                            .font(.subheadline)
                            .foregroundStyle(theme.inkMuted)
                        Text(type.label ?? "")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(theme.ink)
                    }
                }
                if let blurb = type.blurb, !blurb.isEmpty {
                    Text(blurb)
                        .font(.subheadline)
                        .foregroundStyle(theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !traits.isEmpty {
                    FlowChips(items: traits)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct FlowChips: View {
    @Environment(\.marqueeTheme) private var theme
    let items: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { chips }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) { ForEach(items.prefix(2), id: \.self, content: chip) }
                HStack(spacing: 6) { ForEach(items.dropFirst(2), id: \.self, content: chip) }
            }
        }
    }

    private var chips: some View { ForEach(items, id: \.self, content: chip) }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(theme.olive)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(theme.oliveSoft, in: Capsule())
    }
}

// MARK: - This year vs last

struct YearCompareCard: View {
    @Environment(\.marqueeTheme) private var theme
    let year: StatsPeriod
    let previous: StatsPeriod

    private var thisYear: Int { Calendar.current.component(.year, from: Date()) }

    private var change: Int? {
        let now = year.totalMins ?? 0, before = previous.totalMins ?? 0
        guard before > 0 else { return nil }
        return Int((Double(now - before) / Double(before) * 100).rounded())
    }

    var body: some View {
        StatsCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(headline)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                HStack(spacing: 0) {
                    column("\(thisYear)", year, bold: true)
                    Rectangle().fill(theme.border).frame(width: 1, height: 44).padding(.horizontal, 14)
                    column("\(thisYear - 1)", previous, bold: false)
                }
            }
        }
    }

    private var headline: String {
        guard let change else { return "\(thisYear) so far" }
        if change == 0 { return "Level with last year" }
        return change > 0 ? "\(change)% more than last year" : "\(-change)% less than last year"
    }

    private func column(_ label: String, _ p: StatsPeriod, bold: Bool) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.inkMuted)
            Text(StatsFormat.minutes(p.totalMins ?? 0))
                .font(.title3.weight(bold ? .bold : .semibold))
                .foregroundStyle(bold ? theme.ink : theme.inkMuted)
                .monospacedDigit()
            Text("\(p.filmCount ?? 0) films · \(p.episodeCount ?? 0) episodes")
                .font(.caption)
                .foregroundStyle(theme.inkMuted)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Time of day

/// 24 hourly bars; the peak hour is the one hibiscus bar.
struct HourBars: View {
    @Environment(\.marqueeTheme) private var theme
    let rhythm: StatsRhythm

    private var hours: [Int] { (rhythm.byHour ?? []).map { $0.mins ?? 0 } }
    private var peak: Int { rhythm.peakHour ?? hours.indices.max { hours[$0] < hours[$1] } ?? 0 }

    var body: some View {
        StatsCard {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(rhythm.persona ?? "When you watch")
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                    Text(rhythm.caption ?? "Most watching around \(hourLabel(peak))")
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                let top = max(1, hours.max() ?? 1)
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(hours.enumerated()), id: \.offset) { i, mins in
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(i == peak ? theme.accent : theme.olive.opacity(mins > 0 ? 0.55 : 0.12))
                            .frame(height: max(3, 72 * CGFloat(mins) / CGFloat(top)))
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 72, alignment: .bottom)
                HStack {
                    ForEach([0, 6, 12, 18], id: \.self) { h in
                        Text(hourLabel(h)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .font(.caption2)
                .foregroundStyle(theme.inkMuted)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rhythm.persona ?? "Time of day"). Most watching around \(hourLabel(peak)).")
    }

    private func hourLabel(_ h: Int) -> String {
        switch h {
        case 0: return "12 am"
        case 12: return "12 pm"
        default: return h < 12 ? "\(h) am" : "\(h - 12) pm"
        }
    }
}

// MARK: - Hot takes

struct HotTakesList: View {
    @Environment(\.marqueeTheme) private var theme
    let takes: [StatsHotTake]

    var body: some View {
        StatsCard {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hot takes")
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                    Text("Where you and everyone else disagree")
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                }
                ForEach(takes.prefix(5)) { take in
                    row(take)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ take: StatsHotTake) -> some View {
        let label = HStack(spacing: 12) {
            CachedAsyncImage(url: AppConfig.posterURL(path: take.poster, size: "w154"))
                .frame(width: 36, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(take.title ?? "Film")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Text("You ★\(stars(take.userRating)) · Everyone ★\(stars(take.communityRating))")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            Image(systemName: (take.delta ?? 0) > 0 ? "arrow.up" : "arrow.down")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.olive)
                .accessibilityLabel((take.delta ?? 0) > 0 ? "You rated it higher" : "You rated it lower")
        }
        if let id = take.mediaId.flatMap(Int.init) {
            MediaNavLink(id: id, kind: .movie) { label }
        } else {
            label
        }
    }

    private func stars(_ value: Double?) -> String {
        guard let value else { return "–" }
        return value.formatted(.number.precision(.fractionLength(0...1)))
    }
}

// MARK: - Share card

/// A clean olive card for sharing; rendered to an image with ImageRenderer.
struct StatsShareCard: View {
    let name: String
    let stats: DashboardStats

    var body: some View {
        let o = stats.overview
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image("MarqueeMark")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                Text("Marquee")
                    .font(.headline)
            }
            .foregroundStyle(MarqueeColor.saltGrey)

            VStack(alignment: .leading, spacing: 2) {
                Text(name.isEmpty ? "Screen time" : "\(name)’s screen time")
                    .font(.subheadline)
                    .foregroundStyle(MarqueeColor.saltGrey.opacity(0.75))
                Text(StatsFormat.span((o?.tvMins ?? 0) + (o?.filmMins ?? 0)))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(MarqueeColor.saltGrey)
            }

            HStack(spacing: 24) {
                stat("\((o?.episodeCount ?? 0).formatted())", "episodes")
                stat("\((o?.filmCount ?? 0).formatted())", "films")
                stat("\((o?.tvShowCount ?? 0).formatted())", "shows")
            }

            if let show = stats.ranges?.all?.topShows?.first?.tvTitle {
                line("Top show", show)
            }
            if let type = stats.lobbyType?.label {
                line("Watches like", type)
            }
        }
        .padding(28)
        .frame(width: 360, alignment: .leading)
        .background(MarqueeColor.deepOlive)
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { _ in Circle().fill(MarqueeColor.hibiscus).frame(width: 8, height: 8) }
            }
            .padding(28)
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title2.weight(.bold)).foregroundStyle(MarqueeColor.saltGrey)
            Text(label).font(.caption).foregroundStyle(MarqueeColor.saltGrey.opacity(0.75))
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(MarqueeColor.saltGrey.opacity(0.75))
            Spacer()
            Text(value).fontWeight(.semibold).foregroundStyle(MarqueeColor.saltGrey).lineLimit(1)
        }
        .font(.subheadline)
    }

    @MainActor
    static func image(name: String, stats: DashboardStats) -> Image? {
        let renderer = ImageRenderer(content: StatsShareCard(name: name, stats: stats))
        renderer.scale = 3
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
