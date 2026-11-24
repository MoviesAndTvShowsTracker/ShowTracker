import SwiftUI

// MARK: - Lobby timeline rails (Airing soon / Paused)

struct LobbyTimelineRail: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    var subtitle: String? = nil
    let items: [ThisWeekItem]

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(items.prefix(14)) { item in
                            timelineCard(item)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    @ViewBuilder
    private func timelineCard(_ item: ThisWeekItem) -> some View {
        if let tracking = item.tracking, item.kind == .resume {
            NavigationLink {
                TVContinueView(tvId: item.tvId, seed: tracking)
            } label: {
                ThisWeekCardChrome(item: item)
            }
            .buttonStyle(PressablePosterStyle())
        } else {
            NavigationLink {
                TVDetailView(tvId: item.tvId)
            } label: {
                ThisWeekCardChrome(item: item)
            }
            .buttonStyle(PressablePosterStyle())
        }
    }
}

private struct ThisWeekCardChrome: View {
    @Environment(\.marqueeTheme) private var theme
    let item: ThisWeekItem

    var body: some View {
        HStack(spacing: 10) {
            CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath))
                .frame(width: 48, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.chip)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.olive)
                    .textCase(.uppercase)
                    .tracking(0.4)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                Text(item.detail)
                    .font(.caption2)
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(2)
            }
            .frame(width: 148, alignment: .leading)
        }
        .padding(10)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }
}

// MARK: - Lobby empty

struct LobbyEmptyState: View {
    @Environment(\.marqueeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Your Lobby is quiet")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.ink)
            Text("Start a show or bookmark a film — Continue and your queue show up here.")
                .font(.subheadline)
                .foregroundStyle(theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                NavigationLink {
                    MediaBrowseView(kind: .movie)
                } label: {
                    shortcut(title: "Films", systemImage: "film")
                }
                .buttonStyle(PressablePosterStyle())

                NavigationLink {
                    MediaBrowseView(kind: .tv)
                } label: {
                    shortcut(title: "TV", systemImage: "tv")
                }
                .buttonStyle(PressablePosterStyle())
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }

    private func shortcut(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.olive)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(theme.oliveSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: - Week pulse

struct WeekPulseRow: View {
    @Environment(\.marqueeTheme) private var theme
    let recap: WeekRecap

    private var minutes: Int { recap.totalMinsThisWeek ?? 0 }
    private var films: Int { recap.filmsThisWeek ?? 0 }
    private var episodes: Int { recap.episodesThisWeek ?? 0 }
    private var streak: Int { recap.streak ?? 0 }

    var body: some View {
        NavigationLink {
            StatsView()
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This week")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.olive)
                        .textCase(.uppercase)
                        .tracking(0.5)
                    Text(StatsFormat.minutes(minutes))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.ink)
                        .monospacedDigit()
                    Text(pulseSubtitle)
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption2.weight(.bold))
                        Text("\(streak)d")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                    }
                    .foregroundStyle(theme.olive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.oliveSoft, in: Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.olive)
            }
            .padding(16)
            .background(theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressablePosterStyle())
        .padding(.horizontal, 20)
        .accessibilityLabel("This week. \(StatsFormat.minutes(minutes)). Opens stats.")
    }

    private var pulseSubtitle: String {
        switch (films > 0, episodes > 0) {
        case (true, true): return "\(films) films · \(episodes) episodes"
        case (true, false): return "\(films) film\(films == 1 ? "" : "s")"
        case (false, true): return "\(episodes) episode\(episodes == 1 ? "" : "s")"
        default: return "Nothing logged yet"
        }
    }
}

// MARK: - Tonight

struct TonightCard: View {
    @Environment(\.marqueeTheme) private var theme
    let pick: TonightPick

    var body: some View {
        destination {
            HStack(alignment: .center, spacing: 14) {
                CachedAsyncImage(url: AppConfig.posterURL(path: pick.posterPath))
                    .frame(width: 72, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: theme.olive.opacity(0.2), radius: 10, y: 4)

                VStack(alignment: .leading, spacing: 8) {
                    OliveChip(text: pick.chip)
                    Text(pick.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(2)
                    Text(pick.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(2)

                    Text(pick.cta)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.onAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(theme.accent)
                        .clipShape(Capsule())
                        .padding(.top, 2)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(theme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }
        }
        .buttonStyle(PressablePosterStyle())
        .accessibilityLabel("\(pick.chip). \(pick.title). \(pick.subtitle)")
    }

    @ViewBuilder
    private func destination<Label: View>(@ViewBuilder label: @escaping () -> Label) -> some View {
        if let tvId = pick.tvId {
            if let tracking = pick.tracking, tracking.status == "watching" || tracking.status == "paused" {
                NavigationLink {
                    TVContinueView(tvId: tvId, seed: tracking)
                } label: { label() }
            } else {
                MediaNavLink(id: tvId, kind: .tv, label: label)
            }
        } else if let movieId = pick.movieId {
            MediaNavLink(id: movieId, kind: .movie, label: label)
        } else {
            label()
        }
    }
}

// MARK: - Compact rails

struct HomeShowRail: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    var subtitle: String? = nil
    let items: [TrackingRecord]
    var destinationTab: TVLibraryView.LibraryTab? = nil
    var badge: ((TrackingRecord) -> String?)? = nil

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.ink)
                        if let subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(theme.inkMuted)
                        }
                    }
                    Spacer()
                    if let destinationTab {
                        NavigationLink("See all") {
                            TVLibraryView(initialTab: destinationTab)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.olive)
                    }
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items.prefix(12)) { item in
                            NavigationLink {
                                TVDetailView(tvId: Int(item.tvId) ?? 0)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    PosterTile(
                                        title: item.tvTitle ?? "Show",
                                        posterPath: item.posterPath,
                                        year: nil
                                    )
                                    if let badge = badge?(item) {
                                        Text(badge)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(theme.olive)
                                            .lineLimit(1)
                                            .frame(width: 110, alignment: .leading)
                                    }
                                }
                            }
                            .buttonStyle(PressablePosterStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct HomeScheduleRail: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    var subtitle: String? = nil
    let items: [ScheduleEpisode]

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(items.prefix(12)) { item in
                            NavigationLink {
                                TVDetailView(tvId: item.tvId)
                            } label: {
                                HStack(spacing: 10) {
                                    CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath))
                                        .frame(width: 48, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(2)
                                        Text("S\(item.season)E\(item.episode)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(theme.olive)
                                        Text(friendlyDate(item.airDate))
                                            .font(.caption2)
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    .frame(width: 140, alignment: .leading)
                                }
                                .padding(10)
                                .background(theme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(theme.border, lineWidth: 1)
                                )
                            }
                            .buttonStyle(PressablePosterStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func friendlyDate(_ raw: String) -> String {
        let today = dayString(Date())
        if raw == today { return "Today" }
        if let tmr = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
           raw == dayString(tmr) { return "Tomorrow" }
        let parts = raw.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              let date = Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
        else { return raw }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

struct UpNextStrip: View {
    @Environment(\.marqueeTheme) private var theme
    let items: [TrackingRecord]

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text("Up next")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(items.prefix(10)) { item in
                            NavigationLink {
                                TVContinueView(
                                    tvId: Int(item.tvId) ?? 0,
                                    seed: item
                                )
                            } label: {
                                HStack(spacing: 10) {
                                    CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath))
                                        .frame(width: 40, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.tvTitle ?? "Show")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(1)
                                        Text(ShowProgress.from(track: item).episodeLine)
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(theme.olive)
                                        if let name = item.nextEpisodeName, !name.isEmpty {
                                            Text(name)
                                                .font(.caption2)
                                                .foregroundStyle(theme.inkMuted)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(width: 128, alignment: .leading)
                                }
                                .padding(8)
                                .background(theme.oliveSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .buttonStyle(PressablePosterStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

struct ForYouRail: View {
    @Environment(\.marqueeTheme) private var theme
    let items: [HomeRecommendation]

    private var sectionReason: String? {
        items.first?.reason
    }

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("For you")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.ink)
                    if let sectionReason {
                        Text(sectionReason)
                            .font(.subheadline)
                            .foregroundStyle(theme.inkMuted)
                            .lineLimit(2)
                    }
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items) { rec in
                            MediaNavLink(id: rec.item.id, kind: rec.kind) {
                                PosterTile(
                                    title: rec.item.displayTitle,
                                    posterPath: rec.item.poster_path,
                                    year: rec.kind == .tv ? "TV" : "Film"
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

/// JustWatch-style WatchBar: icon tiles, not finicky text capsules.
struct StreamingFilterBar: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selected: Set<Int>
    var showLabels: Bool = false

    private let iconSize: CGFloat = 40

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                anyServiceButton
                ForEach(StreamingProviderOption.allCases) { option in
                    providerButton(option)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
    }

    private var anyServiceButton: some View {
        let isOn = selected.isEmpty
        return Button {
            selected.removeAll()
            Haptics.light()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isOn ? theme.olive : theme.surfaceElevated)
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isOn ? theme.onAccent : theme.olive)
                }
                .frame(width: iconSize, height: iconSize)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isOn ? theme.olive : theme.border, lineWidth: isOn ? 2 : 1)
                }
                .shadow(color: isOn ? theme.olive.opacity(0.22) : .clear, radius: 6, y: 2)

                if showLabels {
                    Text("All")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isOn ? theme.ink : theme.inkMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Any service")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: isOn)
    }

    private func providerButton(_ option: StreamingProviderOption) -> some View {
        let isOn = selected.contains(option.rawValue)
        return Button {
            if isOn {
                selected.remove(option.rawValue)
            } else {
                selected.insert(option.rawValue)
            }
            Haptics.light()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    CachedAsyncImage(
                        url: AppConfig.posterURL(path: option.logoPath, size: "w92"),
                        contentMode: .fill
                    )
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .opacity(isOn || selected.isEmpty ? 1 : 0.42)
                    .saturation(isOn || selected.isEmpty ? 1 : 0.35)

                    if isOn {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(theme.olive, lineWidth: 2.5)
                        VStack {
                            HStack {
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, theme.olive)
                                    .offset(x: 4, y: -4)
                            }
                            Spacer(minLength: 0)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(theme.border.opacity(0.7), lineWidth: 1)
                    }
                }
                .frame(width: iconSize, height: iconSize)
                .shadow(color: isOn ? theme.olive.opacity(0.2) : .clear, radius: 6, y: 2)
                .scaleEffect(isOn ? 1.04 : 1)

                if showLabels {
                    Text(option.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isOn ? theme.ink : theme.inkMuted)
                        .lineLimit(1)
                        .frame(width: iconSize + 8)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: isOn)
        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: selected.isEmpty)
    }
}
