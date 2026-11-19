import SwiftUI

struct WatchlistView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(AppPreferences.self) private var preferences

    enum Scope: String, CaseIterable, Identifiable {
        case all = "All"
        case films = "Films"
        case tv = "TV"
        var id: String { rawValue }
    }

    private struct Entry: Identifiable, Hashable {
        var id: String { "\(kindKey)-\(mediaId)" }
        let mediaId: Int
        let title: String
        let poster: String?
        let kind: MediaKind

        private var kindKey: String { kind == .movie ? "m" : "t" }
    }

    var initialScope: Scope = .all

    @State private var scope: Scope
    @State private var films: [Entry] = []
    @State private var shows: [Entry] = []
    @State private var loading = true
    @State private var error: String?
    @State private var providerFilter = WatchlistProviderFilter()
    @State private var streamingMatchedKeys: Set<String>? = nil
    @State private var streamingFilterBusy = false
    @State private var providerIds: Set<Int> = []

    init(initialScope: Scope = .all) {
        self.initialScope = initialScope
        _scope = State(initialValue: initialScope)
    }

    private var density: GridDensity { preferences.gridDensity }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: density.rawValue)
    }

    private var tileWidth: CGFloat {
        density == .cozy ? 110 : 84
    }

    private var visible: [Entry] {
        let base: [Entry]
        switch scope {
        case .all: base = films + shows
        case .films: base = films
        case .tv: base = shows
        }
        guard let matched = streamingMatchedKeys else { return base }
        return base.filter { matched.contains($0.id) }
    }

    var body: some View {
        Group {
            if loading && films.isEmpty && shows.isEmpty {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<density.rawValue * 3, id: \.self) { _ in
                            SkeletonBlock(height: tileWidth * 1.5 + 40, radius: 12)
                        }
                    }
                    .padding(20)
                }
            } else if let error, films.isEmpty, shows.isEmpty {
                ErrorStateView(message: error) {
                    Task { await load() }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Watchlist", selection: $scope) {
                            ForEach(Scope.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)

                        StreamingFilterBar(selected: $providerIds)

                        if streamingFilterBusy && !providerIds.isEmpty {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Checking what’s on your services…")
                                    .font(.caption)
                                    .foregroundStyle(theme.inkMuted)
                            }
                            .padding(.horizontal, 20)
                        } else if visible.isEmpty {
                            Text(emptyCopy)
                                .font(.subheadline)
                                .foregroundStyle(theme.inkMuted)
                                .padding(.horizontal, 20)
                                .padding(.top, 24)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            LazyVGrid(columns: columns, spacing: 12) {
                                ForEach(visible) { item in
                                    MediaNavLink(id: item.mediaId, kind: item.kind) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            PosterTile(
                                                title: item.title,
                                                posterPath: item.poster,
                                                width: tileWidth
                                            )
                                            Text(item.kind == .movie ? "Film" : "TV")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(theme.olive)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 28)
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
        .marqueeCanvas()
        .navigationTitle("Watchlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GridDensityToggle(density: Bindable(preferences).gridDensity)
            }
        }
        .task { await load() }
        .onChange(of: providerIds) { _, _ in
            Task { await refreshStreamingFilter() }
        }
    }

    private var emptyCopy: String {
        if !providerIds.isEmpty {
            return "Nothing on those services in this filter — try Any service."
        }
        switch scope {
        case .all: return "Nothing queued yet — bookmark a film or show."
        case .films: return "No films on your watchlist."
        case .tv: return "No shows on your watchlist."
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            async let f = DiaryService.movieWatchlist()
            async let t = DiaryService.tvWatchlist()
            let filmDocs = try await f
            let tvDocs = try await t
            films = filmDocs.compactMap { doc in
                guard let id = Int(doc.movieId) else { return nil }
                return Entry(mediaId: id, title: doc.movieTitle ?? "Film", poster: doc.posterPath, kind: .movie)
            }
            shows = tvDocs.compactMap { doc in
                guard let id = Int(doc.tvId) else { return nil }
                return Entry(mediaId: id, title: doc.tvTitle ?? "Show", poster: doc.posterPath, kind: .tv)
            }
            await refreshStreamingFilter()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func refreshStreamingFilter() async {
        let preferred = providerIds
        guard !preferred.isEmpty else {
            streamingMatchedKeys = nil
            streamingFilterBusy = false
            return
        }
        streamingFilterBusy = true
        defer { streamingFilterBusy = false }

        let candidates = films + shows
        var matched = Set<String>()
        await withTaskGroup(of: (String, Bool).self) { group in
            for entry in candidates.prefix(60) {
                group.addTask {
                    let ok = await providerFilter.matches(
                        kind: entry.kind,
                        id: entry.mediaId,
                        preferred: preferred
                    )
                    return (entry.id, ok)
                }
            }
            for await (key, ok) in group where ok {
                matched.insert(key)
            }
        }
        streamingMatchedKeys = matched
    }
}
