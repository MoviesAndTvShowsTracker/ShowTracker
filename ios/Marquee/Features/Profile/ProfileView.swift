import SwiftUI

struct ProfileView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme

    @State private var summary: LibraryCounts?
    @State private var favoritesFilms: [FavoriteMovieDoc] = []
    @State private var watchedFilms: [WatchMovieDoc] = []
    @State private var favoritesTV: [FavoriteTVDoc] = []
    @State private var watchedTV: [FavoriteTVDoc] = []
    @State private var overview: StatsOverview?
    @State private var loading = true
    @State private var error: String?

    private var displayName: String {
        let first = auth.profile?.firstName ?? auth.session?.firstName ?? ""
        return first.isEmpty ? "You" : first
    }

    private var hasDiary: Bool {
        !favoritesFilms.isEmpty || !watchedFilms.isEmpty || !favoritesTV.isEmpty || !watchedTV.isEmpty
            || (summary?.watching ?? 0) > 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if loading && favoritesFilms.isEmpty && watchedFilms.isEmpty {
                    ProfileSkeleton()
                } else {
                    statsTeaser
                    librarySummary
                    if hasDiary {
                        rails
                    } else {
                        emptyOnboarding
                    }
                }

                if let error {
                    Text(error).font(.footnote).foregroundStyle(theme.inkMuted)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .background(theme.surface.ignoresSafeArea())
        .navigationTitle("You")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SettingsView()
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(theme.olive)
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            Text(String(displayName.prefix(1)).uppercased())
                .font(.title.weight(.bold))
                .foregroundStyle(MarqueeColor.saltGrey)
                .frame(width: 56, height: 56)
                .background(theme.olive)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                SectionKicker(text: "Your diary", accented: true)
                Text(displayName)
                    .font(.title.weight(.bold))
                    .foregroundStyle(theme.ink)
                Text(auth.session?.email ?? "")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
        }
    }

    private var statsTeaser: some View {
        NavigationLink {
            StatsView()
        } label: {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionKicker(text: "Estimated watch time")
                        Spacer()
                        Text("All stats")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.olive)
                    }
                    Text(formatMinutes(overview?.totalMins ?? 0))
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(theme.olive)
                    Text(catalogueLine)
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                    TimeSplitBar(
                        films: overview?.filmCount ?? 0,
                        episodes: overview?.episodeCount ?? 0
                    )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var catalogueLine: String {
        let films = overview?.filmCount ?? watchedFilms.count
        let eps = overview?.episodeCount ?? 0
        var parts: [String] = []
        if films > 0 { parts.append("\(films) films") }
        if eps > 0 { parts.append("\(eps) episodes") }
        return parts.isEmpty ? "Start logging to see your rhythm." : parts.joined(separator: " · ")
    }

    private var librarySummary: some View {
        let w = summary?.watching ?? 0
        let p = summary?.paused ?? 0
        let f = summary?.completed ?? 0
        if w + p + f == 0 { return AnyView(EmptyView()) }
        return AnyView(
            NavigationLink {
                TVLibraryView()
            } label: {
                GlassCard(padding: 12) {
                    HStack(spacing: 8) {
                        libraryCell("Watching", w)
                        libraryCell("Paused", p)
                        libraryCell("Finished", f)
                    }
                }
            }
            .buttonStyle(.plain)
        )
    }

    private func libraryCell(_ title: String, _ count: Int) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.olive)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(theme.oliveSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var rails: some View {
        VStack(alignment: .leading, spacing: 22) {
            profileRail("Favorite films", movies: favoritesFilms.map { ($0.movieId, $0.movieTitle ?? "Film", $0.posterPath) }, isTV: false, list: .favoriteFilms)
            profileRail("Watched films", movies: watchedFilms.map { ($0.movieId, $0.movieTitle ?? "Film", $0.posterPath) }, isTV: false, list: .watchedFilms)
            profileRail("Favorite TV", movies: favoritesTV.map { ($0.tvId, $0.tvTitle ?? "Show", $0.posterPath) }, isTV: true, list: .favoriteTV)
            profileRail("Watched TV", movies: watchedTV.map { ($0.tvId, $0.tvTitle ?? "Show", $0.posterPath) }, isTV: true, list: .watchedTV)
        }
    }

    private func profileRail(
        _ title: String,
        movies: [(id: String, title: String, poster: String?)],
        isTV: Bool,
        list: ProfileListKind
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                NavigationLink("View all") {
                    ProfileListView(kind: list)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.olive)
            }
            if movies.isEmpty {
                Text("Nothing here yet.")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(movies, id: \.id) { item in
                            MediaNavLink(id: Int(item.id) ?? 0, kind: isTV ? .tv : .movie) {
                                PosterTile(title: item.title, posterPath: item.poster)
                            }
                        }
                    }
                }
            }
        }
    }

    private var emptyOnboarding: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    SectionKicker(text: "Welcome", accented: true)
                    Text("Your diary is ready for its first entry")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(theme.ink)
                    Text("Log what you watch, save favorites, and build a personal screening room over time.")
                        .foregroundStyle(theme.inkMuted)
                }
            }

            Text("How it works")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.olive)

            VStack(spacing: 10) {
                howStep(1, "Browse", "Find a film or show worth tracking.")
                howStep(2, "Log it", "Mark watched — films and episodes become your diary.")
                howStep(3, "Save favorites", "Heart titles you love so they stay easy to find.")
            }
        }
    }

    private func howStep(_ n: Int, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.headline.weight(.bold))
                .foregroundStyle(theme.olive)
                .frame(width: 32, height: 32)
                .background(theme.oliveSoft)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline).foregroundStyle(theme.ink)
                Text(text).font(.subheadline).foregroundStyle(theme.inkMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func formatMinutes(_ mins: Int) -> String {
        if mins <= 0 { return "—" }
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            async let sum = DiaryService.librarySummary()
            async let ff = DiaryService.favoriteMovies()
            async let wf = DiaryService.watchedMovies()
            async let ft = DiaryService.favoriteTV()
            async let wt = DiaryService.watchedTV()
            async let stats = DiaryService.dashboardStats()
            summary = try await sum.counts
            favoritesFilms = try await ff
            watchedFilms = try await wf
            favoritesTV = try await ft
            watchedTV = try await wt
            overview = try await stats.overview
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct TimeSplitBar: View {
    @Environment(\.marqueeTheme) private var theme
    let films: Int
    let episodes: Int

    var body: some View {
        let total = max(films + episodes, 1)
        let filmShare = CGFloat(films) / CGFloat(total)
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Capsule().fill(theme.olive).frame(width: max(4, geo.size.width * filmShare))
                    Capsule().fill(theme.accent).frame(maxWidth: .infinity)
                }
            }
            .frame(height: 8)
            HStack {
                Label("Films", systemImage: "circle.fill")
                    .foregroundStyle(theme.olive)
                Spacer()
                Label("TV", systemImage: "circle.fill")
                    .foregroundStyle(theme.accent)
            }
            .font(.caption2.weight(.semibold))
            .labelStyle(.titleAndIcon)
        }
    }
}

enum ProfileListKind: String {
    case favoriteFilms, watchedFilms, filmWatchlist, favoriteTV, watchedTV, tvWatchlist

    var title: String {
        switch self {
        case .favoriteFilms: return "Favorite films"
        case .watchedFilms: return "Watched films"
        case .filmWatchlist: return "Film watchlist"
        case .favoriteTV: return "Favorite TV"
        case .watchedTV: return "Watched TV"
        case .tvWatchlist: return "TV watchlist"
        }
    }
}

struct ProfileListView: View {
    @Environment(\.marqueeTheme) private var theme
    let kind: ProfileListKind
    @State private var movies: [(id: String, title: String, poster: String?)] = []
    @State private var isTV = false
    @State private var loading = true
    @AppStorage("marquee.gridDensity") private var densityRaw: Int = GridDensity.cozy.rawValue

    private var density: GridDensity {
        get { GridDensity(rawValue: densityRaw) ?? .cozy }
        nonmutating set { densityRaw = newValue.rawValue }
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: density.rawValue)
    }

    private var tileWidth: CGFloat {
        // Approximate tile width for fixed caption height; grid flexes the rest.
        density == .cozy ? 110 : 84
    }

    var body: some View {
        Group {
            if loading && movies.isEmpty {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<density.rawValue * 3, id: \.self) { _ in
                            SkeletonBlock(height: tileWidth * 1.5 + 40, radius: 12)
                        }
                    }
                    .padding(20)
                }
            } else if movies.isEmpty {
                ContentUnavailableView(kind.title, systemImage: "film", description: Text("Nothing logged yet."))
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(movies, id: \.id) { item in
                            MediaNavLink(id: Int(item.id) ?? 0, kind: isTV ? .tv : .movie) {
                                PosterTile(title: item.title, posterPath: item.poster, width: tileWidth)
                            }
                        }
                    }
                    .padding(20)
                }
            }
        }
        .background(theme.surface.ignoresSafeArea())
        .navigationTitle(kind.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GridDensityToggle(density: Binding(
                    get: { GridDensity(rawValue: densityRaw) ?? .cozy },
                    set: { densityRaw = $0.rawValue }
                ))
            }
        }
        .task { await load() }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            switch kind {
            case .favoriteFilms:
                isTV = false
                movies = try await DiaryService.favoriteMovies().map { ($0.movieId, $0.movieTitle ?? "Film", $0.posterPath) }
            case .watchedFilms:
                isTV = false
                movies = try await DiaryService.watchedMovies().map { ($0.movieId, $0.movieTitle ?? "Film", $0.posterPath) }
            case .filmWatchlist:
                isTV = false
                movies = try await DiaryService.movieWatchlist().map { ($0.movieId, $0.movieTitle ?? "Film", $0.posterPath) }
            case .favoriteTV:
                isTV = true
                movies = try await DiaryService.favoriteTV().map { ($0.tvId, $0.tvTitle ?? "Show", $0.posterPath) }
            case .watchedTV:
                isTV = true
                movies = try await DiaryService.watchedTV().map { ($0.tvId, $0.tvTitle ?? "Show", $0.posterPath) }
            case .tvWatchlist:
                isTV = true
                movies = try await DiaryService.tvWatchlist().map { ($0.tvId, $0.tvTitle ?? "Show", $0.posterPath) }
            }
        } catch {}
    }
}
