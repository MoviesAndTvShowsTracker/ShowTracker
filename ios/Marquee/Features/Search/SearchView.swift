import SwiftUI

struct SearchView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var focusToken: Int

    @State private var query = ""
    @State private var scope: TMDBService.SearchType = .multi
    @State private var results: [MediaItem] = []
    @State private var page = 1
    @State private var totalPages = 1
    @State private var loadingMore = false
    @State private var trending: [MediaItem] = []
    @State private var recent: [String] = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []
    @State private var viewed: [RecentlyViewed] = RecentlyViewed.load()
    @State private var searching = false
    @State private var error: String?
    @State private var debounceTask: Task<Void, Never>?
    @State private var searchPresented = false
    @State private var searchGeneration = 0
    @State private var activeQuery = ""

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var titles: [MediaItem] { results.filter { !isPerson($0) } }
    private var people: [MediaItem] {
        let all = results.filter { isPerson($0) && $0.profile_path != nil }
        if scope == .person { return all }
        // In All, only strong matches: the top hit, or a name that starts with the query.
        let q = activeQuery.lowercased()
        return all.filter { $0.id == results.first?.id || $0.displayTitle.lowercased().hasPrefix(q) }
    }

    /// A wide card when the first title closely matches what was typed.
    private var topResult: MediaItem? {
        guard scope != .person, let first = titles.first, first.backdrop_path != nil else { return nil }
        let q = activeQuery.lowercased()
        return first.displayTitle.lowercased().hasPrefix(q) ? first : nil
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
            prompt: "Films, shows, people"
        )
        .searchSuggestions {
            if trimmedQuery.isEmpty {
                ForEach(recent.prefix(5), id: \.self) { term in
                    Label(term, systemImage: "clock.arrow.circlepath").searchCompletion(term)
                }
            }
        }
        .searchScopes($scope, activation: .onSearchPresentation) {
            ForEach(TMDBService.SearchType.allCases) { Text($0.label).tag($0) }
        }
        // Without this, an active search session on push ignores the detail's
        // `.toolbar(.hidden)` and kills the soft scroll-edge blur. iOS 18+ system bug.
        .searchPresentationToolbarBehavior(.avoidHidingContent)
        .onChange(of: query) { _, _ in scheduleSearch() }
        .onChange(of: scope) { _, _ in scheduleSearch(immediate: true) }
        .onChange(of: focusToken) { _, _ in searchPresented = true }
        .task {
            async let trend: Void = loadTrending()
            async let films: Void = FilmDiaryIndex.shared.refresh()
            async let shows: Void = TVDiaryIndex.shared.refresh()
            _ = await (trend, films, shows)
        }
    }

    // MARK: - Idle

    private var idleState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if !viewed.isEmpty { viewedSection }
                if !trending.isEmpty { trendingSection }
                browseTiles
            }
            .padding(.vertical, 12)
            .padding(.bottom, 28)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private var viewedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            CatalogShelfHeader(
                title: "Recently viewed",
                seeAll: AnyView(
                    Button("Clear") {
                        withAnimation(reduceMotion ? nil : MarqueeMotion.micro) { viewed = [] }
                        RecentlyViewed.save([])
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.olive)
                )
            )
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 10) {
                    ForEach(viewed) { entry in
                        MediaNavLink(id: entry.id, kind: entry.mediaKind) {
                            PosterTile(title: entry.title, posterPath: entry.poster, width: 84, captionLines: 1)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            CatalogShelfHeader(title: "Trending today")
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(trending.prefix(14)) { item in
                        MediaNavLink(id: item.id, kind: kind(for: item)) {
                            PosterTile(
                                title: item.displayTitle,
                                posterPath: item.poster_path,
                                year: kind(for: item) == .tv ? "TV" : item.year
                            )
                        }
                        .catalogQuickActions(item, kind: kind(for: item))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var browseTiles: some View {
        VStack(alignment: .leading, spacing: 12) {
            CatalogShelfHeader(title: "Browse")
            HStack(spacing: 10) {
                browseTile("Films", systemImage: "film", kind: .movie)
                browseTile("TV", systemImage: "tv", kind: .tv)
            }
            .padding(.horizontal, 20)
        }
    }

    private func browseTile(_ title: String, systemImage: String, kind: MediaKind) -> some View {
        NavigationLink {
            MediaBrowseView(kind: kind)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.olive)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.border, lineWidth: 1))
        }
        .buttonStyle(PressablePosterStyle())
        .accessibilityLabel("Browse \(kind == .movie ? "films" : "TV")")
    }

    // MARK: - Results

    private let resultColumns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if searching && results.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView().tint(theme.accent)
                        Text("Searching…")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else if !searching, results.isEmpty, let error {
                    ErrorStateView(message: error) { scheduleSearch(immediate: true) }
                        .padding(.top, 12)
                } else if !searching, results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 24)
                } else {
                    if let top = topResult {
                        TopResultCard(item: top, kind: kind(for: top))
                            .simultaneousGesture(TapGesture().onEnded { remember(top) })
                    }

                    if !people.isEmpty {
                        if scope == .person {
                            peopleGrid
                        } else {
                            FacesRail(people: people.prefix(12).map(asPerson), title: "People")
                        }
                    }

                    let grid = titles.filter { $0.id != topResult?.id }
                    if !grid.isEmpty {
                        LazyVGrid(columns: resultColumns, spacing: 14) {
                            ForEach(grid) { item in
                                MediaNavLink(id: item.id, kind: kind(for: item)) {
                                    PosterGridTile(
                                        title: item.displayTitle,
                                        posterPath: item.poster_path,
                                        caption: resultCaption(for: item),
                                        kindLabel: scope == .multi ? (kind(for: item) == .tv ? "TV" : "Film") : nil
                                    )
                                }
                                .buttonStyle(PressablePosterStyle())
                                .simultaneousGesture(TapGesture().onEnded { remember(item) })
                                .catalogQuickActions(item, kind: kind(for: item))
                                .onAppear {
                                    if item.id == grid.last?.id { Task { await loadMore() } }
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    if loadingMore {
                        ProgressView().tint(theme.accent).frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.bottom, 28)
            .animation(reduceMotion ? nil : MarqueeMotion.micro, value: results.map(\.id))
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private var peopleGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 18) {
            ForEach(people) { person in
                NavigationLink { PersonView(personId: person.id) } label: {
                    VStack(spacing: 6) {
                        CachedAsyncImage(url: AppConfig.posterURL(path: person.profile_path, size: "w185"), contentMode: .fill)
                            .frame(width: 84, height: 84)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(theme.border, lineWidth: 1))
                        Text(person.displayTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        Text(role(person.known_for_department))
                            .font(.caption2)
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                .buttonStyle(PressablePosterStyle())
            }
        }
        .padding(.horizontal, 20)
    }

    private func resultCaption(for item: MediaItem) -> String? {
        var parts: [String] = []
        if let year = item.year { parts.append(year) }
        if let vote = item.vote_average, vote > 0 { parts.append(String(format: "★ %.1f", vote)) }
        return parts.isEmpty ? nil : parts.joined(separator: "  ")
    }

    // MARK: - Helpers

    private func kind(for item: MediaItem) -> MediaKind {
        if scope == .movie { return .movie }
        if scope == .tv { return .tv }
        let t = item.media_type ?? (item.title != nil ? "movie" : "tv")
        return t == "tv" ? .tv : .movie
    }

    private func isPerson(_ item: MediaItem) -> Bool {
        scope == .person || item.media_type == "person"
    }

    private func role(_ department: String?) -> String {
        switch department {
        case "Directing": return "Director"
        case "Writing": return "Writer"
        case "Acting": return "Actor"
        default: return department ?? ""
        }
    }

    private func asPerson(_ item: MediaItem) -> TrendingPerson {
        TrendingPerson(id: item.id, name: item.displayTitle, profile_path: item.profile_path,
                       known_for_department: item.known_for_department, known_for: nil)
    }

    private func remember(_ item: MediaItem) {
        let entry = RecentlyViewed(id: item.id, kind: kind(for: item) == .tv ? "tv" : "movie",
                                   title: item.displayTitle, poster: item.poster_path)
        viewed = Array(([entry] + viewed.filter { $0 != entry }).prefix(12))
        RecentlyViewed.save(viewed)
    }

    private func setRecent(_ terms: [String]) {
        withAnimation(reduceMotion ? nil : MarqueeMotion.micro) { recent = terms }
        UserDefaults.standard.set(terms, forKey: "recentSearches")
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
            if !immediate { try? await Task.sleep(nanoseconds: 320_000_000) }
            guard !Task.isCancelled else { return }
            await runSearch(for: q)
        }
    }

    private func runSearch(for q: String) async {
        searchGeneration += 1
        let generation = searchGeneration
        let type = scope
        searching = true
        defer { if generation == searchGeneration { searching = false } }

        do {
            let res = try await TMDBService.search(query: q, type: type)
            guard !Task.isCancelled, generation == searchGeneration, trimmedQuery == q else { return }
            results = res.results.filter(keep)
            page = 1
            totalPages = res.total_pages ?? 1
            activeQuery = q
            error = nil
            if !recent.contains(q) { setRecent(Array(([q] + recent).prefix(8))) }
        } catch {
            guard !Task.isCancelled, generation == searchGeneration, !isCancellation(error) else { return }
            if results.isEmpty { self.error = friendlyMessage(for: error) }
        }
    }

    private func loadMore() async {
        guard !loadingMore, !searching, page < totalPages, page < 5, !activeQuery.isEmpty else { return }
        loadingMore = true
        defer { loadingMore = false }
        let generation = searchGeneration
        guard let res = try? await TMDBService.search(query: activeQuery, type: scope, page: page + 1),
              generation == searchGeneration else { return }
        let seen = Set(results.map(\.id))
        results += res.results.filter { keep($0) && !seen.contains($0.id) }
        page += 1
    }

    private func keep(_ item: MediaItem) -> Bool {
        if scope == .person { return true }
        let t = item.media_type
        return t == nil || t == "movie" || t == "tv" || t == "person"
    }

    private func loadTrending() async {
        guard trending.isEmpty else { return }
        trending = (try? await TMDBService.fetchPaged("trending/all/day"))?.results
            .filter { $0.media_type == "movie" || $0.media_type == "tv" } ?? []
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


/// A title opened from Search, newest first.
struct RecentlyViewed: Codable, Identifiable, Hashable {
    let id: Int
    let kind: String
    let title: String
    let poster: String?

    var mediaKind: MediaKind { kind == "tv" ? .tv : .movie }

    static func == (a: Self, b: Self) -> Bool { a.id == b.id && a.kind == b.kind }
    func hash(into h: inout Hasher) { h.combine(id); h.combine(kind) }

    private static let key = "search.recentlyViewed"

    static func load() -> [RecentlyViewed] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentlyViewed].self, from: data)) ?? []
    }

    static func save(_ items: [RecentlyViewed]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: key)
    }
}
