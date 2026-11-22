import SwiftUI

/// Films / TV discovery — filters live here, not on Search.
/// Pattern: Letterboxd/JustWatch browse (known-item search stays lean).
struct MediaBrowseView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let kind: MediaKind
    var initialGenreId: Int? = nil
    var initialProviders: Set<Int>? = nil

    @State private var sort: BrowseSort = .popular
    @State private var genreId: Int? = nil
    @State private var providerIds: Set<Int> = []
    @State private var items: [MediaItem] = []
    @State private var page = 1
    @State private var totalPages = 1
    @State private var loading = true
    @State private var loadingMore = false
    @State private var error: String?
    @State private var loadGeneration = 0
    @State private var suppressFilterReload = true

    private var density: GridDensity { preferences.gridDensity }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 12), count: density.rawValue)
    }

    private var tileWidth: CGFloat {
        density == .cozy ? 110 : 84
    }

    private var query: BrowseQuery {
        BrowseQuery(
            kind: kind,
            sort: sort,
            genreId: genreId,
            providerIds: providerIds,
            watchRegion: preferences.resolvedWatchRegion,
            page: page
        )
    }

    private var title: String {
        kind == .movie ? "Browse films" : "Browse TV"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                filterChrome
                summaryLine

                if loading && items.isEmpty {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(0..<density.rawValue * 3, id: \.self) { _ in
                            SkeletonBlock(height: tileWidth * 1.5 + 40, radius: 12)
                        }
                    }
                    .padding(.horizontal, 20)
                } else if let error, items.isEmpty {
                    ErrorStateView(message: error) {
                        Task { await reload() }
                    }
                    .padding(.top, 12)
                } else if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing matches",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: Text("Loosen a filter — try Any genre or Any service.")
                    )
                    .padding(.top, 24)
                } else {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(items) { item in
                            MediaNavLink(id: item.id, kind: kind) {
                                PosterTile(
                                    title: item.displayTitle,
                                    posterPath: item.poster_path,
                                    width: tileWidth,
                                    year: item.year
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .animation(reduceMotion ? nil : MarqueeMotion.micro, value: items.map(\.id))

                    if page < totalPages {
                        Button {
                            Task { await loadMore() }
                        } label: {
                            HStack(spacing: 8) {
                                if loadingMore { ProgressView().tint(theme.onAccent) }
                                Text(loadingMore ? "Loading…" : "Show more")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(loadingMore)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                    }
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .marqueeCanvas()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                GridDensityToggle(density: Bindable(preferences).gridDensity)
            }
        }
        .task {
            suppressFilterReload = true
            if genreId == nil { genreId = initialGenreId }
            if providerIds.isEmpty {
                providerIds = initialProviders ?? preferences.preferredProviderIds
            }
            await reload()
            suppressFilterReload = false
        }
        .onChange(of: sort) { _, _ in
            guard !suppressFilterReload else { return }
            Task { await reload() }
        }
        .onChange(of: genreId) { _, _ in
            guard !suppressFilterReload else { return }
            Task { await reload() }
        }
        .onChange(of: providerIds) { _, newValue in
            guard !suppressFilterReload else { return }
            preferences.preferredProviderIds = newValue
            Task { await reload() }
        }
    }

    private var filterChrome: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Sort", selection: $sort) {
                ForEach(BrowseSort.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    genreChip(title: "Any genre", selected: genreId == nil) {
                        genreId = nil
                    }
                    ForEach(BrowseGenre.catalog(for: kind)) { genre in
                        genreChip(title: genre.name, selected: genreId == genre.id) {
                            genreId = genre.id
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            StreamingFilterBar(selected: $providerIds)
        }
    }

    private var summaryLine: some View {
        Text(query.summary)
            .font(.subheadline)
            .foregroundStyle(theme.inkMuted)
            .padding(.horizontal, 20)
            .accessibilityLabel(query.summary)
    }

    private func genreChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            withAnimation(reduceMotion ? nil : MarqueeMotion.micro) {
                action()
            }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? theme.onAccent : theme.olive)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? theme.olive : theme.oliveSoft)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func reload() async {
        loadGeneration += 1
        let generation = loadGeneration
        page = 1
        loading = true
        error = nil
        defer {
            if generation == loadGeneration { loading = false }
        }
        do {
            var q = query
            q.page = 1
            let pageResult = try await TMDBService.discover(q)
            guard generation == loadGeneration else { return }
            items = pageResult.results
            totalPages = max(1, pageResult.total_pages ?? 1)
        } catch {
            guard generation == loadGeneration else { return }
            if items.isEmpty {
                self.error = error.localizedDescription
            }
        }
    }

    private func loadMore() async {
        guard !loadingMore, page < totalPages else { return }
        loadingMore = true
        defer { loadingMore = false }
        let next = page + 1
        var q = query
        q.page = next
        do {
            let pageResult = try await TMDBService.discover(q)
            let existing = Set(items.map(\.id))
            let fresh = pageResult.results.filter { !existing.contains($0.id) }
            items.append(contentsOf: fresh)
            page = next
            totalPages = max(totalPages, pageResult.total_pages ?? totalPages)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
