import SwiftUI

struct SearchView: View {
    @Environment(\.marqueeTheme) private var theme
    @Binding var focusToken: Int

    @State private var query = ""
    @State private var type: TMDBService.SearchType = .multi
    @State private var results: [MediaItem] = []
    @State private var trending: [MediaItem] = []
    @State private var recent: [String] = UserDefaults.standard.stringArray(forKey: "recentSearches") ?? []
    @State private var searching = false
    @State private var error: String?
    @State private var debounceTask: Task<Void, Never>?
    @State private var searchPresented = false
    @State private var searchGeneration = 0
    @State private var activeQuery = ""

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
        .navigationBarTitleDisplayMode(.large)
        .searchable(
            text: $query,
            isPresented: $searchPresented,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Films and shows"
        )
        .onChange(of: query) { _, _ in
            scheduleSearch()
        }
        .onChange(of: type) { _, _ in
            scheduleSearch(immediate: true)
        }
        .onChange(of: focusToken) { _, _ in
            searchPresented = true
        }
        .task {
            if trending.isEmpty {
                trending = (try? await TMDBService.fetchPaged("trending/all/week"))?.results
                    .filter { isFilmOrShow($0) } ?? []
            }
        }
    }

    private var idleState: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                typeChips
                    .padding(.horizontal, 20)

                browseShortcuts
                    .padding(.horizontal, 20)

                if !recent.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recent")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(theme.ink)
                            Spacer()
                            Button("Clear") {
                                recent = []
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
                                            .background(theme.oliveSoft)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(PressablePosterStyle())
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }

                if !trending.isEmpty {
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
                                            year: item.year
                                        )
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }

    private var browseShortcuts: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Or browse")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.ink)
            Text("Filter by service and genre when you’re exploring — Search stays for titles you know.")
                .font(.subheadline)
                .foregroundStyle(theme.inkMuted)

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

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                typeChips
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

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
                        .padding(.bottom, 8)
                    }

                    ForEach(results) { item in
                        MediaNavLink(id: item.id, kind: kind(for: item)) {
                            SearchResultRow(item: item)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private var typeChips: some View {
        HStack(spacing: 8) {
            ForEach(TMDBService.SearchType.allCases) { t in
                Button {
                    withAnimation(MarqueeMotion.micro) { type = t }
                    Haptics.light()
                } label: {
                    Text(t.label)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(type == t ? theme.onAccent : theme.olive)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(type == t ? theme.olive : theme.oliveSoft)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
        }
    }

    private func kind(for item: MediaItem) -> MediaKind {
        let t = item.media_type ?? (item.title != nil ? "movie" : "tv")
        return t == "tv" ? .tv : .movie
    }

    private func isFilmOrShow(_ item: MediaItem) -> Bool {
        let kind = item.media_type
        return kind == "movie" || kind == "tv" || kind == nil
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
        // Keep current results on screen while typing; only clear the hard error.
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
            let page = try await TMDBService.search(query: q, type: type)
            guard !Task.isCancelled, generation == searchGeneration else { return }
            // Drop stale responses if the query moved on.
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
            // Only surface a hard error when we have nothing useful to show.
            if results.isEmpty {
                self.error = friendlyMessage(for: error)
            }
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

struct SearchResultRow: View {
    @Environment(\.marqueeTheme) private var theme
    let item: MediaItem

    private var kindLabel: String {
        let t = item.media_type ?? (item.title != nil ? "movie" : "tv")
        return t == "tv" ? "TV" : "Film"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(url: AppConfig.posterURL(path: item.poster_path))
                .frame(width: 56, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.displayTitle)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 8) {
                    Text(kindLabel)
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.olive)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.oliveSoft)
                        .clipShape(Capsule())
                    if let year = item.year {
                        Text(year)
                            .font(.caption)
                            .foregroundStyle(theme.inkMuted)
                    }
                    if let vote = item.vote_average, vote > 0 {
                        Label(String(format: "%.1f", vote), systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                    }
                }

                if let overview = item.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
