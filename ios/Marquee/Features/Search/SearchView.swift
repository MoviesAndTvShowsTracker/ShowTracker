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

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
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
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 280_000_000)
                guard !Task.isCancelled else { return }
                await runSearch()
            }
        }
        .onChange(of: type) { _, _ in
            Task { await runSearch() }
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
                                        Task { await runSearch() }
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

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                typeChips
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)

                if searching && results.isEmpty {
                    ProgressView()
                        .tint(theme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                        .padding(.top, 24)
                } else {
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

    private func runSearch() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard q.count >= 2 else {
            results = []
            return
        }
        searching = true
        defer { searching = false }
        do {
            let page = try await TMDBService.search(query: q, type: type)
            results = page.results.filter { isFilmOrShow($0) }
            if !recent.contains(q) {
                recent.insert(q, at: 0)
                recent = Array(recent.prefix(8))
                UserDefaults.standard.set(recent, forKey: "recentSearches")
            }
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
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
