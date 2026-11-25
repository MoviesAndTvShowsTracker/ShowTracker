import SwiftUI

private struct SectionHeader<Trailing: View>: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.ink)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 20)
    }
}

private extension View {
    func homeCard(_ theme: MarqueeTheme) -> some View {
        background(theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.border, lineWidth: 1))
    }

    func trailingLink(_ theme: MarqueeTheme) -> some View {
        font(.caption.weight(.semibold)).foregroundStyle(theme.olive)
    }
}

// MARK: - This week

struct AgendaSection: View {
    @Environment(\.marqueeTheme) private var theme
    let rows: [AgendaRow]

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "This week") { EmptyView() }
                VStack(spacing: 0) {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 { Divider().overlay(theme.border).padding(.leading, 90) }
                        NavigationLink { TVDetailView(tvId: row.episode.tvId) } label: { rowView(row) }
                            .buttonStyle(.plain)
                    }
                }
                .homeCard(theme)
                .padding(.horizontal, 20)
            }
        }
    }

    private func rowView(_ row: AgendaRow) -> some View {
        let ep = row.episode
        let detail = ep.kind == "returning"
            ? "Season \(ep.season) returns"
            : "S\(ep.season)E\(ep.episode)" + (ep.episodeName.map { " · \($0)" } ?? "")
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.dayLabel ?? "")
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .tracking(MarqueeType.labelTracking)
                .foregroundStyle(theme.olive)
                .frame(width: 64, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(ep.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - Recently logged

struct RecentlyLoggedSection: View {
    @Environment(\.marqueeTheme) private var theme
    let items: [DiaryActivityItem]
    let today: Date

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Recently logged") {
                    NavigationLink("Calendar") { DiaryActivityView() }
                        .trailingLink(theme)
                        .accessibilityIdentifier("watch-calendar-link")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items) { item in tile(item) }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    @ViewBuilder
    private func tile(_ item: DiaryActivityItem) -> some View {
        let poster = PosterTile(
            title: item.title ?? "",
            posterPath: item.posterPath,
            width: 96,
            year: HomeFeedLogic.recentCaption(item, today: today)
        )
        if let id = item.mediaId.flatMap(Int.init) {
            if item.kind == "film" {
                MediaNavLink(id: id, kind: .movie) { poster }
            } else {
                NavigationLink { TVDetailView(tvId: id) } label: { poster }
                    .buttonStyle(PressablePosterStyle())
            }
        } else {
            poster
        }
    }
}

// MARK: - Queue

struct QueueSection: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let films: [FavoriteMovieDoc]
    let tv: [FavoriteTVDoc]
    @State private var scope: WatchlistView.Scope?

    /// Films first, unless only shows are saved.
    private var active: WatchlistView.Scope { scope ?? (films.isEmpty ? .tv : .films) }

    var body: some View {
        if !films.isEmpty || !tv.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Watchlist") {
                    NavigationLink("All") { WatchlistView(initialScope: active) }
                        .trailingLink(theme)
                }

                HStack(spacing: 8) {
                    pill("Films", count: films.count, scope: .films)
                    pill("TV", count: tv.count, scope: .tv)
                }
                .padding(.horizontal, 20)

                Group {
                    if active == .films {
                        rail(isEmpty: films.isEmpty, empty: "No films saved yet.") {
                            ForEach(films.prefix(12), id: \.movieId) { f in
                                if let id = Int(f.movieId) {
                                    MediaNavLink(id: id, kind: .movie) {
                                        PosterTile(title: f.movieTitle ?? "Film", posterPath: f.posterPath)
                                    }
                                }
                            }
                        }
                    } else {
                        rail(isEmpty: tv.isEmpty, empty: "No shows saved yet.") {
                            ForEach(tv.prefix(12), id: \.tvId) { s in
                                if let id = Int(s.tvId) {
                                    MediaNavLink(id: id, kind: .tv) {
                                        PosterTile(title: s.tvTitle ?? "Show", posterPath: s.posterPath)
                                    }
                                }
                            }
                        }
                    }
                }
                .id(active)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: active == .films ? .leading : .trailing)))
            }
            .animation(reduceMotion ? nil : MarqueeMotion.standard, value: active)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home-watchlist")
        }
    }

    private func pill(_ title: String, count: Int, scope target: WatchlistView.Scope) -> some View {
        let selected = active == target
        return Button {
            guard !selected else { return }
            Haptics.light()
            scope = target
        } label: {
            HStack(spacing: 6) {
                Text(title)
                Text("\(count)")
                    .monospacedDigit()
                    .foregroundStyle(selected ? theme.olive.opacity(0.75) : theme.inkMuted)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(selected ? theme.olive : theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(selected ? theme.oliveSoft : theme.surfaceElevated, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selected ? theme.olive.opacity(0.35) : theme.border, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PressablePosterStyle())
        .accessibilityLabel("\(title), \(count) saved")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private func rail<Content: View>(isEmpty: Bool, empty: String, @ViewBuilder content: () -> Content) -> some View {
        if isEmpty {
            Text(empty)
                .font(.subheadline)
                .foregroundStyle(theme.inkMuted)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) { content() }
                    .padding(.horizontal, 20)
            }
        }
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
            // Your numbers live on the olive panel (same surface as Stats / You).
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("This week")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(MarqueeColor.saltGrey.opacity(0.7))
                        .textCase(.uppercase)
                        .tracking(MarqueeType.labelTracking)
                    Text(StatsFormat.minutes(minutes))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MarqueeColor.saltGrey)
                        .monospacedDigit()
                    Text(pulseSubtitle)
                        .font(.caption)
                        .foregroundStyle(MarqueeColor.saltGrey.opacity(0.7))
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
                    .foregroundStyle(MarqueeColor.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(theme.accent, in: Capsule())
                    .accessibilityLabel("\(streak)-day streak")
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(MarqueeColor.saltGrey.opacity(0.7))
            }
            .padding(16)
            .background(OlivePanel(cornerRadius: 18))
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

