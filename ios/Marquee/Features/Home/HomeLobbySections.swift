import SwiftUI

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
    private func destination(@ViewBuilder label: () -> some View) -> some View {
        if let tvId = pick.tvId {
            if let tracking = pick.tracking, tracking.status == "watching" || tracking.status == "paused" {
                NavigationLink {
                    TVContinueView(tvId: tvId, seed: tracking)
                } label: { label() }
            } else {
                NavigationLink { TVDetailView(tvId: tvId) } label: { label() }
            }
        } else if let movieId = pick.movieId {
            NavigationLink { MovieDetailView(movieId: movieId) } label: { label() }
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
                                            .foregroundStyle(theme.accent)
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
                                            .foregroundStyle(theme.accent)
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
                                            .foregroundStyle(theme.accent)
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

struct StreamingFilterBar: View {
    @Environment(\.marqueeTheme) private var theme
    @Binding var selected: Set<Int>

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "Any service", selected: selected.isEmpty) {
                    selected.removeAll()
                }
                ForEach(StreamingProviderOption.allCases) { option in
                    filterChip(
                        title: option.title,
                        selected: selected.contains(option.rawValue)
                    ) {
                        if selected.contains(option.rawValue) {
                            selected.remove(option.rawValue)
                        } else {
                            selected.insert(option.rawValue)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? theme.onAccent : theme.olive)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? theme.olive : theme.oliveSoft)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(MarqueeMotion.micro, value: selected)
    }
}
