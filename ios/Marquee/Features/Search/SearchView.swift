import SwiftUI

struct SearchView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var focusToken: Int

    @State private var query = ""
    @State private var results: [MediaItem] = []
    @State private var trending: [MediaItem] = []
    @State private var recent: [String] = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []
    @State private var searching = false
    @State private var error: String?
    @State private var debounceTask: Task<Void, Never>?
    @State private var searchPresented = false
    @State private var searchGeneration = 0
    @State private var activeQuery = ""

    @State private var watchedMovieIds: Set<Int> = []
    @State private var watchedMovieCounts: [Int: Int] = [:]
    @State private var watchlistMovieIds: Set<Int> = []
    @State private var watchedTVIds: Set<Int> = []
    @State private var watchlistTVIds: Set<Int> = []

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            if trimmedQuery.count < 2 {
                idleState
            } else {
                resultsList
            }
        }
        .marqueeCanvas()
        .navigationTitle("Search")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $query,
            isPresented: $searchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Title, show, or franchise"
        )
        // Without this, an active search session on push ignores the detail's
        // `.toolbar(.hidden)` and kills the soft scroll-edge blur (Films/TV
        // path is fine because it has no searchable). iOS 18+ system bug.
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .onChange(of: query) { _, _ in
            scheduleSearch()
        }
        .onChange(of: focusToken) { _, _ in
            searchPresented = true
        }
        .task {
            async let trend: Void = loadTrending()
            async let diary: Void = loadDiaryMarks()
            _ = await (trend, diary)
        }
    }

    // MARK: - Idle

    private var idleState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                browseShortcuts
                    .padding(.horizontal, 20)

                if !recent.isEmpty {
                    recentSection
                }

                if !trending.isEmpty {
                    trendingSection
                }
            }
            .padding(.vertical, 12)
            .padding(.bottom, 28)
        }
    }

    private var browseShortcuts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Browse instead")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.ink)
            Text("Service and genre filters live on Films and TV — Search is for titles you already have in mind.")
                .font(.subheadline)
                .foregroundStyle(theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                NavigationLink {
                    MediaBrowseView(kind: .movie)
                } label: {
                    browseShortcutLabel(title: "Films", systemImage: "film")
                }
                .buttonStyle(PressablePosterStyle())

                NavigationLink {
                    MediaBrowseView(kind: .tv)
                } label: {
                    browseShortcutLabel(title: "TV", systemImage: "tv")
                }
                .buttonStyle(PressablePosterStyle())
            }
        }
    }

    private func browseShortcutLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer(minLength: 0)
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.accent)
        }
        .foregroundStyle(theme.olive)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Button("Clear") {
                    withAnimation(reduceMotion ? nil : MarqueeMotion.micro) {
                        recent = []
                    }
                    UserDefaults.standard.set(recent, forKey: "recentSearches")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.olive)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recent, id: \.self) { term in
                        Button {
                            query = term
                            searchPresented = true
                            scheduleSearch(immediate: true)
                        } label: {
                            Label(term, systemImage: "clock")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.olive)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(theme.oliveSoft, in: Capsule(style: .continuous))
                        }
                        .buttonStyle(PressablePosterStyle())
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Popular right now")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 20)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(trending.prefix(12)) { item in
                        MediaNavLink(id: item.id, kind: kind(for: item)) {
                            PosterTile(
                                title: item.displayTitle,
                                posterPath: item.poster_path,
                                year: item.year,
                                diary: diaryMark(for: item)
                            )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Results

    private let resultColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                if searching && results.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(theme.accent)
                        Text("Searching…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else if !searching, results.isEmpty, let error {
                    ErrorStateView(message: error) {
                        scheduleSearch(immediate: true)
                    }
                    .padding(.top, 12)
                } else if !searching, results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 24)
                } else {
                    if searching, !results.isEmpty, activeQuery != trimmedQuery {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                                .tint(theme.accent)
                            Text("Updating…")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.inkMuted)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 20)
                    }

                    LazyVGrid(columns: resultColumns, spacing: 14) {
                        ForEach(results) { item in
                            MediaNavLink(id: item.id, kind: kind(for: item)) {
                                PosterGridTile(
                                    title: item.displayTitle,
                                    posterPath: item.poster_path,
                                    caption: resultCaption(for: item),
                                    diary: diaryMark(for: item),
                                    kindLabel: kind(for: item) == .tv ? "TV" : "Film"
                                )
                            }
                            .buttonStyle(PressablePosterStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
            .padding(.vertical, 8)
            .animation(reduceMotion ? nil : MarqueeMotion.micro, value: results.map(\.id))
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func resultCaption(for item: MediaItem) -> String? {
        var parts: [String] = []
        if let year = item.year { parts.append(year) }
        if let vote = item.vote_average, vote > 0 {
            parts.append(String(format: "%.1f", vote))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - Helpers

    private func kind(for item: MediaItem) -> MediaKind {
        let t = item.media_type ?? (item.title != nil ? "movie" : "tv")
        return t == "tv" ? .tv : .movie
    }

    private func isFilmOrShow(_ item: MediaItem) -> Bool {
        let kind = item.media_type
        return kind == "movie" || kind == "tv" || kind == nil
    }

    private func diaryMark(for item: MediaItem) -> DiaryStatusMark? {
        switch kind(for: item) {
        case .movie:
            if watchedMovieIds.contains(item.id) {
                return .watched(times: watchedMovieCounts[item.id] ?? 1)
            }
            if watchlistMovieIds.contains(item.id) { return .watchlist }
        case .tv:
            if watchedTVIds.contains(item.id) { return .watched(times: 1) }
            if watchlistTVIds.contains(item.id) { return .watchlist }
        }
        return nil
    }

    private func scheduleSearch(immediate: Bool = false) {
        debounceTask?.cancel()
        let q = trimmedQuery
        guard q.count >= 2 else {
            searching = false
            error = nil
            results = []
            activeQuery = ""
            return
        }
        error = nil
        debounceTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 320_000_000)
            }
            guard !Task.isCancelled else { return }
            await runSearch(for: q)
        }
    }

    private func runSearch(for q: String) async {
        searchGeneration += 1
        let generation = searchGeneration
        searching = true
        defer {
            if generation == searchGeneration {
                searching = false
            }
        }

        do {
            async let pageTask = TMDBService.search(query: q, type: .multi)
            async let diaryTask: Void = loadDiaryMarks()
            let page = try await pageTask
            _ = await diaryTask
            guard !Task.isCancelled, generation == searchGeneration else { return }
            guard trimmedQuery == q || immediateMatch(q) else { return }
            results = page.results.filter { isFilmOrShow($0) }
            activeQuery = q
            error = nil
            if !recent.contains(q) {
                recent.insert(q, at: 0)
                recent = Array(recent.prefix(8))
                UserDefaults.standard.set(recent, forKey: "recentSearches")
            }
        } catch is CancellationError {
            return
        } catch let urlError as URLError where urlError.code == .cancelled {
            return
        } catch {
            guard !Task.isCancelled, generation == searchGeneration else { return }
            if isCancellation(error) { return }
            if results.isEmpty {
                self.error = friendlyMessage(for: error)
            }
        }
    }

    private func loadTrending() async {
        guard trending.isEmpty else { return }
        trending = (try? await TMDBService.fetchPaged("trending/all/week"))?.results
            .filter { isFilmOrShow($0) } ?? []
    }

    private func loadDiaryMarks() async {
        async let films = DiaryService.watchedMovies()
        async let filmList = DiaryService.movieWatchlist()
        async let shows = DiaryService.watchedTV()
        async let showList = DiaryService.tvWatchlist()

        if let watched = try? await films {
            watchedMovieIds = Set(watched.compactMap { Int($0.movieId) })
            watchedMovieCounts = Dictionary(uniqueKeysWithValues: watched.compactMap { doc in
                guard let id = Int(doc.movieId) else { return nil }
                return (id, max(1, doc.watchCount ?? 1))
            })
        }
        if let list = try? await filmList {
            watchlistMovieIds = Set(list.compactMap { Int($0.movieId) })
        }
        if let watched = try? await shows {
            watchedTVIds = Set(watched.compactMap { Int($0.tvId) })
        }
        if let list = try? await showList {
            watchlistTVIds = Set(list.compactMap { Int($0.tvId) })
        }
    }

    private func immediateMatch(_ q: String) -> Bool {
        trimmedQuery == q
    }

    private func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if let api = error as? APIError, case .transport(let inner) = api {
            return isCancellation(inner)
        }
        let ns = error as NSError
        return ns.domain == NSURLErrorDomain && ns.code == NSURLErrorCancelled
    }

    private func friendlyMessage(for error: Error) -> String {
        if let api = error as? APIError {
            return api.errorDescription ?? "Search failed."
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return "No internet connection."
            case NSURLErrorTimedOut:
                return "Search timed out. Try again."
            default:
                break
            }
        }
        return error.localizedDescription
    }
}

