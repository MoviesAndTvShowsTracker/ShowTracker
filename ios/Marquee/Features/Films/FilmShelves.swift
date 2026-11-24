import SwiftUI

// MARK: - Self-loading shelf

/// Loads its own rows when scrolled near (inside a LazyVStack), caches them for 6 hours,
/// and refetches when `refresh` changes. Keeps the Films tab's first paint to three requests.
struct LazyShelf<Element: Codable & Sendable, Content: View>: View {
    let key: String
    let refresh: Int
    let load: () async throws -> [Element]
    @ViewBuilder let content: ([Element]) -> Content
    @State private var items: [Element]?
    @State private var loadedRefresh: Int?

    private let maxAge: TimeInterval = 6 * 60 * 60

    var body: some View {
        Group {
            if let items {
                if !items.isEmpty { content(items) }
            } else {
                RailSkeleton()
            }
        }
        .task(id: "\(key)#\(refresh)") {
            if items == nil, let cached = ResponseCache.load([Element].self, key: key, maxAge: maxAge) {
                items = cached
                loadedRefresh = refresh
                return
            }
            guard loadedRefresh != refresh || items == nil else { return }
            if let fresh = try? await load() {
                items = fresh
                ResponseCache.store(fresh, key: key)
            } else if items == nil {
                items = []
            }
            loadedRefresh = refresh
        }
    }
}

// MARK: - Coming soon (dated rows)

struct ComingSoonSection: View {
    @Environment(\.marqueeTheme) private var theme
    let items: [MediaItem]
    var kind: MediaKind = .movie
    var title = "Coming soon"

    private func queued(_ id: Int) -> Bool {
        kind == .movie ? FilmDiaryIndex.shared.watchlist.contains(id) : TVDiaryIndex.shared.watchlist.contains(id)
    }

    private func toggle(_ item: MediaItem) async throws {
        if kind == .movie { try await FilmDiaryIndex.shared.toggleWatchlist(item) } else { try await TVDiaryIndex.shared.toggleWatchlist(item) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CatalogShelfHeader(title: title)
            VStack(spacing: 0) {
                ForEach(Array(items.prefix(6).enumerated()), id: \.element.id) { i, item in
                    if i > 0 { Divider().overlay(theme.border).padding(.leading, 86) }
                    row(item)
                }
            }
            .background(theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.border, lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }

    private func row(_ item: MediaItem) -> some View {
        let date = FilmDates.day(item.release_date ?? item.first_air_date)
        let queued = queued(item.id)
        return HStack(spacing: 12) {
            MediaNavLink(id: item.id, kind: kind) {
                HStack(spacing: 12) {
                    VStack(spacing: 0) {
                        Text(date.map { $0.formatted(.dateTime.month(.abbreviated)) } ?? "")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.inkMuted)
                        Text(date.map { $0.formatted(.dateTime.day()) } ?? "–")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(theme.ink)
                            .monospacedDigit()
                    }
                    .frame(width: 40)
                    CachedAsyncImage(url: AppConfig.posterURL(path: item.poster_path, size: "w154"))
                        .frame(width: 34, height: 51)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.displayTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                        Text(date.map { $0.formatted(.dateTime.weekday(.wide)) } ?? "Date to be announced")
                            .font(.caption)
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }

            Button {
                Task {
                    do { try await toggle(item); Haptics.light() } catch {
                        Feedback.failed("Couldn't update your watchlist. Try again.")
                    }
                }
            } label: {
                Image(systemName: queued ? "bookmark.fill" : "bookmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.olive)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(queued ? "Remove \(item.displayTitle) from watchlist" : "Add \(item.displayTitle) to watchlist")
        }
        .padding(.leading, 12)
        .padding(.trailing, 4)
        .padding(.vertical, 8)
    }
}

// MARK: - Faces this week

struct FacesRail: View {
    @Environment(\.marqueeTheme) private var theme
    let people: [TrendingPerson]
    var title = "Faces this week"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CatalogShelfHeader(title: title)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 16) {
                    ForEach(people.prefix(16)) { person in
                        NavigationLink { PersonView(personId: person.id) } label: {
                            VStack(spacing: 6) {
                                CachedAsyncImage(url: AppConfig.posterURL(path: person.profile_path, size: "w185"), contentMode: .fill)
                                    .frame(width: 76, height: 76)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(theme.border, lineWidth: 1))
                                Text(person.name)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.ink)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                                Text(person.known_for_department == "Directing" ? "Director" : person.known_for_department == "Writing" ? "Writer" : "Actor")
                                    .font(.caption2)
                                    .foregroundStyle(theme.inkMuted)
                            }
                            .frame(width: 84)
                        }
                        .buttonStyle(PressablePosterStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Browse card (genres + decades)

/// One quiet card at the end of the page: genres as a two-column list, decades underneath.
struct MediaBrowseCard: View {
    @Environment(\.marqueeTheme) private var theme
    let kind: MediaKind
    let genres: [BrowseGenre]
    private let decades = [1970, 1980, 1990, 2000, 2010, 2020]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CatalogShelfHeader(
                title: kind == .movie ? "Browse films" : "Browse TV",
                seeAll: AnyView(
                    NavigationLink("All filters") { MediaBrowseView(kind: kind) }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.olive)
                )
            )

            VStack(spacing: 0) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(Array(stride(from: 0, to: genres.count, by: 2)), id: \.self) { i in
                        if i > 0 { Divider().overlay(theme.border).gridCellUnsizedAxes(.horizontal) }
                        GridRow {
                            genreCell(genres[i])
                            if i + 1 < genres.count {
                                genreCell(genres[i + 1])
                                    .overlay(alignment: .leading) {
                                        Rectangle().fill(theme.border).frame(width: 1)
                                    }
                            }
                        }
                    }
                }

                Divider().overlay(theme.border)

                HStack(spacing: 0) {
                    ForEach(decades, id: \.self) { start in
                        NavigationLink {
                            MediaBrowseView(kind: kind, years: start...(start + 9))
                        } label: {
                            Text("\(String(start).suffix(2))s")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.olive)
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, minHeight: 48)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(kind == .movie ? "Films" : "Shows") from the \(start)s")
                    }
                }
            }
            .background(theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.border, lineWidth: 1))
            .padding(.horizontal, 20)
        }
    }

    private func genreCell(_ genre: BrowseGenre) -> some View {
        NavigationLink {
            MediaBrowseView(kind: kind, initialGenreId: genre.id)
        } label: {
            HStack {
                Text(genre.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.ink)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Queries

enum FilmShelfQueries {
    static func dayString(_ offset: Int) -> String {
        let date = Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
        return HomeFeedLogic.key(date, Calendar.current)
    }

    /// Recently on streaming; limited to the user's services when they picked any.
    static func newOnStreaming(providers: Set<Int>, region: String) async throws -> [MediaItem] {
        var params = [
            "sort_by": "popularity.desc",
            "with_release_type": "4|5",
            "release_date.gte": dayString(-60),
            "release_date.lte": dayString(0),
            "region": region,
            "watch_region": region,
            "with_watch_monetization_types": "flatrate|free|ads",
        ]
        if !providers.isEmpty {
            let ids = providers.reduce(into: Set<Int>()) { out, raw in
                out.formUnion(StreamingProviderOption(rawValue: raw)?.aliases ?? [raw])
            }
            params["with_watch_providers"] = ids.map(String.init).sorted().joined(separator: "|")
        }
        return try await TMDBService.discoverMovies(params)
    }

    static func comingSoon() async throws -> [MediaItem] {
        try await TMDBService.discoverMovies([
            "sort_by": "popularity.desc",
            "with_release_type": "2|3",
            "primary_release_date.gte": dayString(1),
            "primary_release_date.lte": dayString(75),
        ])
        .filter { $0.poster_path != nil }
        .prefix(6)
        .sorted { ($0.release_date ?? "") < ($1.release_date ?? "") }
    }

    /// Proven, well-liked films under 95 minutes (older than a few months so ratings have settled).
    static func shortAndGreat() async throws -> [MediaItem] {
        try await TMDBService.discoverMovies([
            "sort_by": "popularity.desc",
            "vote_average.gte": "7.2",
            "vote_count.gte": "1500",
            "with_runtime.gte": "60",
            "with_runtime.lte": "95",
            "primary_release_date.lte": dayString(-180),
        ])
    }

    /// Well rated but little seen: a few hundred votes, not thousands.
    static func hiddenGems() async throws -> [MediaItem] {
        try await TMDBService.discoverMovies([
            "sort_by": "popularity.desc",
            "vote_average.gte": "7.3",
            "vote_count.gte": "300",
            "vote_count.lte": "2500",
            "primary_release_date.gte": "1990-01-01",
            "primary_release_date.lte": dayString(-180),
        ])
    }

    static func topRated() async throws -> [MediaItem] {
        // TMDB's top_rated list lets brand-new titles with few votes in; require a real consensus.
        try await TMDBService.discoverMovies([
            "sort_by": "vote_average.desc",
            "vote_count.gte": "5000",
        ])
    }

    static func recommendations(for id: Int) async throws -> [MediaItem] {
        try await TMDBService.fetchPaged("movie/\(id)/recommendations").results
    }

    static func faces() async throws -> [TrendingPerson] {
        try await TMDBService.trendingPeople().filter {
            $0.profile_path != nil
                && ["Acting", "Directing"].contains($0.known_for_department ?? "")
                && ($0.known_for ?? []).contains { $0.media_type == "movie" }
        }
    }
}

enum FilmDates {
    static func day(_ raw: String?) -> Date? {
        raw.flatMap { HomeFeedLogic.day($0, Calendar.current) }
    }
}
