import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme

    @State private var summary: LibraryCounts?
    @State private var favoritesFilms: [FavoriteMovieDoc] = []
    @State private var watchedFilms: [WatchMovieDoc] = []
    @State private var favoritesTV: [FavoriteTVDoc] = []
    @State private var watchedTV: [FavoriteTVDoc] = []
    @State private var overview: StatsOverview?
    @State private var ready = false
    @State private var error: String?
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: UIImage? = ProfileAvatarStore.load()

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
                if !ready {
                    ProfileSkeleton()
                } else {
                    header
                    NavigationLink {
                        DiaryActivityView()
                    } label: {
                        HStack {
                            Label("Diary feed", systemImage: "book")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.olive)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.olive)
                        }
                        .padding(12)
                        .background(theme.oliveSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    statsTeaser
                    librarySummary
                    if hasDiary {
                        rails
                    } else {
                        emptyOnboarding
                    }
                }

                if let error {
                    InlineErrorBanner(message: error) {
                        Task { await load() }
                    }
                    .padding(.horizontal, -20)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
        }
        .marqueeCanvas()
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
            PhotosPicker(selection: $avatarItem, matching: .images) {
                ZStack {
                    if let avatarImage {
                        Image(uiImage: avatarImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(.title.weight(.bold))
                            .foregroundStyle(MarqueeColor.saltGrey)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(theme.olive)
                    }
                }
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .onChange(of: avatarItem) { _, item in
                Task {
                    guard let item,
                          let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return }
                    avatarImage = image
                    ProfileAvatarStore.save(image)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                SectionKicker(text: "Your diary", accented: true)
                Text(displayName)
                    .font(.title.weight(.bold))
                    .foregroundStyle(theme.ink)
                Text(auth.session?.email ?? "")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                if let since = memberSince {
                    Text("Member since \(since)")
                        .font(.caption)
                        .foregroundStyle(theme.olive)
                }
            }
            Spacer()
        }
    }

    private var memberSince: String? {
        guard let raw = auth.profile?.createdAt, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return String(raw.prefix(4)) }
        return date.formatted(.dateTime.month(.abbreviated).year())
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
                    Text(StatsFormat.span(overview?.totalMins ?? 0))
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(theme.olive)
                        .minimumScaleFactor(0.65)
                        .lineLimit(1)
                        .monospacedDigit()
                    Text(catalogueLine)
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                    TimeSplitBar(
                        filmMins: overview?.filmMins ?? 0,
                        tvMins: overview?.tvMins ?? 0,
                        filmShare: overview?.filmShare,
                        tvShare: overview?.tvShare
                    )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var catalogueLine: String {
        let films = overview?.filmCount ?? watchedFilms.count
        let eps = overview?.episodeCount ?? 0
        let shows = overview?.tvShowCount ?? 0
        var parts: [String] = []
        if films > 0 { parts.append("\(films) films") }
        if shows > 0, eps > 0 {
            parts.append("\(shows) TV shows (\(eps) episodes)")
        } else if eps > 0 {
            parts.append("\(eps) TV episodes")
        } else if shows > 0 {
            parts.append("\(shows) TV shows")
        }
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

    private func load() async {
        do {
            async let sum = DiaryService.librarySummary()
            async let ff = DiaryService.favoriteMovies()
            async let wf = DiaryService.watchedMovies()
            async let ft = DiaryService.favoriteTV()
            async let wt = DiaryService.watchedTV()
            async let stats = DiaryService.dashboardStats()
            let counts = try await sum.counts
            let favFilms = try await ff
            let watched = try await wf
            let favTV = try await ft
            let watchedShows = try await wt
            let dash = try await stats.overview
            var transaction = Transaction()
            transaction.disablesAnimations = !ready
            withTransaction(transaction) {
                summary = counts
                favoritesFilms = favFilms
                watchedFilms = watched
                favoritesTV = favTV
                watchedTV = watchedShows
                overview = dash
                ready = true
                error = nil
            }
        } catch {
            self.error = error.localizedDescription
            ready = true
        }
    }
}

struct TimeSplitBar: View {
    @Environment(\.marqueeTheme) private var theme
    let filmMins: Int
    let tvMins: Int
    var filmShare: Int? = nil
    var tvShare: Int? = nil

    private var filmFraction: CGFloat {
        let shareTotal = (filmShare ?? 0) + (tvShare ?? 0)
        if shareTotal > 0 {
            return CGFloat(filmShare ?? 0) / CGFloat(shareTotal)
        }
        let total = max(filmMins + tvMins, 1)
        return CGFloat(filmMins) / CGFloat(total)
    }

    var body: some View {
        if filmMins + tvMins <= 0, (filmShare ?? 0) + (tvShare ?? 0) <= 0 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                GeometryReader { geo in
                    let hasFilms = filmMins > 0 || (filmShare ?? 0) > 0
                    let hasTV = tvMins > 0 || (tvShare ?? 0) > 0
                    HStack(spacing: 2) {
                        if hasFilms {
                            Capsule()
                                .fill(theme.olive)
                                .frame(width: hasTV ? max(4, geo.size.width * filmFraction) : nil)
                                .frame(maxWidth: hasTV ? nil : .infinity)
                        }
                        if hasTV {
                            Capsule().fill(theme.accent).frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: 8)
                HStack(alignment: .firstTextBaseline) {
                    legend(theme.olive, "Films")
                    Spacer()
                    legend(theme.accent, "TV shows (episodes)")
                }
            }
        }
    }

    private func legend(_ color: Color, _ title: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
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
    @Environment(AppPreferences.self) private var preferences

    private var density: GridDensity { preferences.gridDensity }

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
        .marqueeCanvas()
        .navigationTitle(kind.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GridDensityToggle(density: Bindable(preferences).gridDensity)
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
