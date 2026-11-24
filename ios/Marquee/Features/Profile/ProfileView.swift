import SwiftUI
import PhotosUI

struct ProfileView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme

    @State private var favoritesFilms: [FavoriteMovieDoc] = []
    @State private var watchedFilms: [WatchMovieDoc] = []
    @State private var favoritesTV: [FavoriteTVDoc] = []
    @State private var watchedTV: [FavoriteTVDoc] = []
    @State private var stats: DashboardStats? = DiaryService.cachedDashboardStats()
    @State private var ready = false
    @State private var error: String?
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarImage: UIImage? = ProfileAvatarStore.load()
    @State private var showStats = UITestingFixtures.startTab == "stats"

    private typealias Entry = (id: String, title: String, poster: String?)

    private var displayName: String {
        let first = auth.profile?.firstName ?? auth.session?.firstName ?? ""
        return first.isEmpty ? "You" : first
    }

    private var hasDiary: Bool {
        !favoritesFilms.isEmpty || !watchedFilms.isEmpty || !favoritesTV.isEmpty || !watchedTV.isEmpty
    }

    private var favFilmEntries: [Entry] { favoritesFilms.map { ($0.movieId, $0.movieTitle ?? "Film", $0.posterPath) } }
    private var favTVEntries: [Entry] { favoritesTV.map { ($0.tvId, $0.tvTitle ?? "Show", $0.posterPath) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !ready {
                    ProfileSkeleton().padding(.horizontal, 20)
                } else {
                    header
                    statsTeaser
                    if let type = stats?.lobbyType, let label = type.label, !label.isEmpty {
                        viewerType(label: label, blurb: type.blurb)
                    }
                    if hasDiary {
                        profileRail("Watched films", items: watchedFilms.map { ($0.movieId, $0.movieTitle ?? "Film", $0.posterPath) }, isTV: false, list: .watchedFilms)
                        profileRail("Favorite films", items: favFilmEntries, isTV: false, list: .favoriteFilms)
                        profileRail("Watched TV", items: watchedTV.map { ($0.tvId, $0.tvTitle ?? "Show", $0.posterPath) }, isTV: true, list: .watchedTV)
                        profileRail("Favorite TV", items: favTVEntries, isTV: true, list: .favoriteTV)
                        badgesTeaser
                    } else {
                        emptyOnboarding.padding(.horizontal, 20)
                    }
                    moreLinks
                }

                if let error {
                    InlineErrorBanner(message: error) { Task { await load() } }
                }
            }
            .padding(.vertical, 16)
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
                .accessibilityLabel("Settings")
            }
        }
        .navigationDestination(isPresented: $showStats) { StatsView() }
        .task { await load() }
        .refreshable { await load() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .center, spacing: 16) {
            PhotosPicker(selection: $avatarItem, matching: .images) {
                ZStack {
                    if let avatarImage {
                        Image(uiImage: avatarImage).resizable().scaledToFill()
                    } else {
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(MarqueeColor.saltGrey)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(theme.olive)
                    }
                }
                .frame(width: 76, height: 76)
                .clipShape(Circle())
                .overlay(Circle().stroke(theme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Change profile photo")
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
                Text(displayName)
                    .font(.title.weight(.bold))
                    .foregroundStyle(theme.ink)
                if let line = headerLine {
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    /// "Member since Jul 2026 · 987 nights in the dark"
    private var headerLine: String? {
        var parts: [String] = []
        if let since = memberSince { parts.append("Member since \(since)") }
        if let nights = stats?.activity?.activeDays, nights > 0 {
            parts.append("\(nights.formatted()) night\(nights == 1 ? "" : "s") in the dark")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var memberSince: String? {
        guard let raw = auth.profile?.createdAt, !raw.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return String(raw.prefix(4)) }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    /// TV Time-style glance: TV and film time side by side, tap for the full page.
    private var statsTeaser: some View {
        NavigationLink {
            StatsView()
        } label: {
            ScreenTimeStrip(overview: stats?.overview)
        }
        .buttonStyle(PressableRowStyle())
        .accessibilityHint("Opens your stats")
        .padding(.horizontal, 20)
    }

    private func viewerType(label: String, blurb: String?) -> some View {
        NavigationLink {
            StatsView()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "theatermasks.fill")
                    .font(.title3)
                    .foregroundStyle(theme.olive)
                    .frame(width: 40, height: 40)
                    .background(theme.oliveSoft, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                    if let blurb, !blurb.isEmpty {
                        Text(blurb)
                            .font(.subheadline)
                            .foregroundStyle(theme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.border, lineWidth: 1))
        }
        .buttonStyle(PressableRowStyle())
        .padding(.horizontal, 20)
        .accessibilityLabel("Your viewer type: \(label). \(blurb ?? "")")
    }

    // MARK: Rails

    @ViewBuilder
    private func profileRail(_ title: String, items: [Entry], isTV: Bool, list: ProfileListKind) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                CatalogShelfHeader(
                    title: title,
                    seeAll: AnyView(
                        NavigationLink("All \(items.count.formatted())") { ProfileListView(kind: list) }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.olive)
                    )
                )
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items.prefix(15), id: \.id) { item in
                            MediaNavLink(id: Int(item.id) ?? 0, kind: isTV ? .tv : .movie) {
                                PosterTile(title: item.title, posterPath: item.poster, width: 104)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: Badges

    @ViewBuilder
    private var badgesTeaser: some View {
        let badges = BadgeCatalog.badges(from: stats)
        let earned = badges.filter(\.earned)
        if !earned.isEmpty {
            NavigationLink {
                StatsView()
            } label: {
                HStack(spacing: 14) {
                    HStack(spacing: -10) {
                        ForEach(earned.suffix(4)) { badge in
                            BadgeMedal(badge: badge, size: 40)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Badges")
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                        Text("\(earned.count) of \(badges.count) earned")
                            .font(.subheadline)
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.inkMuted)
                }
                .padding(16)
                .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.border, lineWidth: 1))
            }
            .buttonStyle(PressableRowStyle())
            .padding(.horizontal, 20)
        }
    }

    // MARK: More

    private var moreLinks: some View {
        VStack(spacing: 0) {
            linkRow("Watchlist", systemImage: "bookmark") { WatchlistView() }
            Divider().overlay(theme.border).padding(.leading, 52)
            linkRow("TV library", systemImage: "rectangle.stack") { TVLibraryView() }
            Divider().overlay(theme.border).padding(.leading, 52)
            linkRow("Watch calendar", systemImage: "calendar") { DiaryActivityView() }
        }
        .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.border, lineWidth: 1))
        .padding(.horizontal, 20)
    }

    private func linkRow<D: View>(_ title: String, systemImage: String, @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(theme.olive)
                    .frame(width: 24)
                Text(title)
                    .font(.body)
                    .foregroundStyle(theme.ink)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var emptyOnboarding: some View {
        VStack(alignment: .leading, spacing: 16) {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
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
            async let ff = DiaryService.favoriteMovies()
            async let wf = DiaryService.watchedMovies()
            async let ft = DiaryService.favoriteTV()
            async let wt = DiaryService.watchedTV()
            let (favFilms, watched, favTV, watchedShows) = try await (ff, wf, ft, wt)
            var transaction = Transaction()
            transaction.disablesAnimations = !ready
            withTransaction(transaction) {
                favoritesFilms = favFilms
                watchedFilms = watched
                favoritesTV = favTV
                watchedTV = watchedShows
                ready = true
                error = nil
            }
        } catch {
            self.error = error.localizedDescription
            ready = true
        }
        // Screen time never blocks the page: cached copy first, fresh one when it lands.
        if let fresh = try? await DiaryService.dashboardStats() {
            withAnimation(MarqueeMotion.standard) { stats = fresh }
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
        } catch {
            Feedback.failed("Couldn't load that list. Pull to refresh.")
        }
    }
}
