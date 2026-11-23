import SwiftUI

struct MovieDetailView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let movieId: Int

    @State private var detail: MovieDetail?
    @State private var favorited = false
    @State private var watched = false
    @State private var watchCount = 0
    @State private var lastWatchedAt: String?
    @State private var watchlisted = false
    @State private var rating: Double = 0
    @State private var diaryReady = false
    @Environment(AppPreferences.self) private var preferences
    @State private var providers: [WatchProvider] = []
    @State private var providerRegion: String?
    @State private var ratings: MediaRatings?
    @State private var ratingsReady = false
    @State private var phase: LoadPhase = .loading
    @State private var busy = false
    @State private var showWatchActions = false
    @State private var showRatingSheet = false

    private enum LoadPhase { case loading, ready, failed(String) }
    private var idString: String { String(movieId) }

    private var watchSubtitle: String? {
        guard watched else { return nil }
        if watchCount > 1 { return "×\(watchCount)" }
        if let label = shortWatchDate(lastWatchedAt) { return label }
        return "Logged"
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                DetailPageSkeleton()
            case .failed(let message):
                ContentUnavailableView("Couldn’t load", systemImage: "exclamationmark.triangle", description: Text(message))
            case .ready:
                if let detail { content(detail) }
            }
        }
        .marqueeDetailCanvas()
        .navigationBarBackButtonHidden(true)
        .background(EnableSwipeBack())
        // Use `.alert` (centered system dialog), not `.confirmationDialog`.
        // On iOS 26, confirmationDialog presents as a glass popover with a pointer.
        .alert(
            watchCount > 1 ? "Watched ×\(watchCount)" : "Watched",
            isPresented: $showWatchActions
        ) {
            Button("Log again") {
                Task { if let detail { await performWatch(detail, isRewatch: true) } }
            }
            if watchCount > 1 {
                Button("Remove last log") {
                    Task { if let detail { await performUnwatch(detail, mode: "latest") } }
                }
            }
            Button(watchCount > 1 ? "Clear all watches" : "Remove from watched", role: .destructive) {
                Task { if let detail { await performUnwatch(detail, mode: "all") } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(watchCount > 1
                ? "Log again keeps older dates. Remove last log only drops the newest entry."
                : "Log again adds a new dated watch, or remove this film from watched.")
        }
        .sheet(isPresented: $showRatingSheet) {
            ratingSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task { await load() }
    }

    private func content(_ detail: MovieDetail) -> some View {
        MediaDetailShell(
            backdropPath: detail.backdrop_path ?? detail.poster_path,
            title: detail.displayTitle,
            metaParts: MediaMetaLine.parts(
                year: detail.year,
                runtimeMinutes: detail.runtime
            ),
            genresLine: detail.genres?.prefix(3).map(\.name).joined(separator: "  ·  "),
            shareText: shareText(for: detail),
            onBack: { dismiss() },
            actions: {
                if diaryReady {
                    DiaryGlassStrip {
                        diaryButtons(detail)
                        if watched { ratingRow }
                    }
                } else {
                    DiaryGlassStrip {
                        HStack(spacing: 10) {
                            SkeletonBlock(height: 40, radius: 20)
                            SkeletonBlock(height: 40, radius: 20)
                            SkeletonBlock(height: 40, radius: 20)
                        }
                    }
                }
            },
            content: {
                RatingsStrip(ratings: ratings, isLoading: !ratingsReady)
                WatchProvidersRow(providers: providers, region: providerRegion)

                if let overview = detail.overview, !overview.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionKicker(text: "Synopsis")
                        ExpandableText(text: overview)
                    }
                }

                CreditsRows(rows: creditRows(for: detail))

                MediaCastRail(cast: castItems(from: detail))

                if let similar = detail.similar?.results, !similar.isEmpty {
                    NavigationRail(title: "More like this", items: similar, kind: .movie)
                        .padding(.horizontal, -20)
                }
            }
        )
    }

    @ViewBuilder
    private func diaryButtons(_ detail: MovieDetail) -> some View {
        HStack(spacing: 8) {
            ActionStripButton(
                title: favorited ? "Favorited" : "Favorite",
                systemImage: favorited ? "heart.fill" : "heart",
                active: favorited
            ) { Task { await toggleFavorite(detail) } }

            ActionStripButton(
                title: "Watched",
                systemImage: watched ? "eye.fill" : "eye",
                subtitle: watchSubtitle,
                active: watched
            ) {
                if watched {
                    showWatchActions = true
                } else {
                    Task { await performWatch(detail, isRewatch: false) }
                }
            }

            if !watched {
                ActionStripButton(
                    title: watchlisted ? "On list" : "Watchlist",
                    systemImage: watchlisted ? "bookmark.fill" : "bookmark",
                    active: watchlisted
                ) { Task { await toggleWatchlist(detail) } }
            }
            Spacer(minLength: 0)
        }
        .disabled(busy)
    }

    private var ratingRow: some View {
        Button { showRatingSheet = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your rating")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.ink)
                    if rating > 0 {
                        StarRatingView(rating: $rating, editable: false, size: .body)
                    } else {
                        Text("Tap to rate")
                            .font(.caption)
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.olive)
            }
            .padding(.top, 4)
        }
        .buttonStyle(.plain)
    }

    private var ratingSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(detail?.displayTitle ?? "Film")
                    .font(.title3.weight(.bold))
                Text("How was it?")
                    .foregroundStyle(theme.inkMuted)
                StarRatingView(rating: $rating, size: .largeTitle)
                    .frame(maxWidth: .infinity)
                Spacer()
                Button("Save rating") {
                    Task {
                        try? await DiaryService.rateMovie(id: idString, rating: max(1, rating * 2))
                        showRatingSheet = false
                        Haptics.success()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(rating <= 0)
            }
            .padding(24)
            .marqueeCanvas()
            .navigationTitle("Rate film")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showRatingSheet = false }
                }
            }
        }
    }

    private func shareText(for detail: MovieDetail) -> String {
        var parts = [detail.displayTitle]
        if let year = detail.year { parts.append("(\(year))") }
        parts.append("— logged on Marquee")
        return parts.joined(separator: " ")
    }

    private func creditRows(for detail: MovieDetail) -> [CreditRow] {
        let crew = detail.credits?.crew ?? []
        let directors = CreditRow.uniquePeople(crew, jobs: ["Director"], limit: 4)
        let writers = CreditRow.uniquePeople(crew, jobs: ["Writer", "Screenplay", "Story"], limit: 4)
        var rows: [CreditRow] = []
        if !directors.isEmpty {
            rows.append(
                CreditRow(
                    label: directors.count == 1 ? "Director" : "Directors",
                    value: directors.map(\.name).joined(separator: ", "),
                    people: directors
                )
            )
        }
        if !writers.isEmpty {
            rows.append(
                CreditRow(
                    label: "Writing",
                    value: writers.map(\.name).joined(separator: ", "),
                    people: writers
                )
            )
        }
        return rows
    }

    private func castItems(from detail: MovieDetail) -> [(id: Int, name: String, character: String?, profilePath: String?)] {
        (detail.credits?.cast ?? []).prefix(16).compactMap { member in
            guard let name = member.name, !name.isEmpty else { return nil }
            return (id: member.id, name: name, character: member.character, profilePath: member.profile_path)
        }
    }

    private func bodyPayload(_ detail: MovieDetail) -> MovieIdBody {
        MovieIdBody(
            movieId: idString,
            movieTitle: detail.title,
            moviePosterImage: detail.poster_path,
            movieRuntime: detail.runtime.map(String.init)
        )
    }

    private func applyWatchedSummary(
        watched flag: Bool?,
        count: Int?,
        watchedAt: String?,
        ratingValue: Double?
    ) {
        let nextCount = max(0, count ?? (flag == true ? 1 : 0))
        watchCount = nextCount
        watched = nextCount > 0
        lastWatchedAt = watchedAt
        if let r = ratingValue {
            rating = min(5, r > 5 ? r / 2 : r)
        } else if nextCount == 0 {
            rating = 0
        }
    }

    private func shortWatchDate(_ iso: String?) -> String? {
        guard let iso, iso.count >= 10 else { return nil }
        let day = String(iso.prefix(10))
        let parts = day.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              let date = Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
        else { return nil }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }

    private func load() async {
        phase = .loading
        diaryReady = false
        do {
            async let detailTask = TMDBService.movieDetail(id: movieId)
            async let f = DiaryService.movieFavorited(id: idString)
            async let w = DiaryService.movieWatched(id: idString)
            async let l = DiaryService.movieWatchlisted(id: idString)
            let region = await MainActor.run { preferences.resolvedWatchRegion }
            async let providersTask = WatchProviderService.load(kind: .movie, id: movieId, preferredRegion: region)
            async let ratingsTask = RatingsService.load(kind: .movie, id: movieId)
            detail = try await detailTask
            let loadedProviders = await providersTask
            providers = loadedProviders.providers
            providerRegion = loadedProviders.region
            ratings = await ratingsTask
            ratingsReady = true
            favorited = (try? await f) ?? false
            if let watchedRes = try? await w {
                applyWatchedSummary(
                    watched: watchedRes.watched,
                    count: watchedRes.watchCount,
                    watchedAt: watchedRes.watchedAt,
                    ratingValue: watchedRes.rating
                )
            }
            watchlisted = (try? await l) ?? false
            diaryReady = true
            phase = .ready
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func toggleFavorite(_ detail: MovieDetail) async {
        busy = true
        defer { busy = false }
        do {
            if favorited {
                try await DiaryService.removeMovieFavorite(id: idString)
                favorited = false
            } else {
                try await DiaryService.addMovieFavorite(bodyPayload(detail))
                favorited = true
            }
            Haptics.light()
        } catch {}
    }

    private func performWatch(_ detail: MovieDetail, isRewatch: Bool) async {
        busy = true
        defer { busy = false }
        let previousCount = watchCount
        let previousWatchedAt = lastWatchedAt
        watched = true
        watchCount = previousCount + 1
        lastWatchedAt = ISO8601DateFormatter().string(from: Date())
        if isRewatch { Haptics.medium() } else { Haptics.success() }
        do {
            let res = try await DiaryService.addMovieWatched(bodyPayload(detail))
            applyWatchedSummary(
                watched: true,
                count: res.watchCount ?? (previousCount + 1),
                watchedAt: res.watchedAt ?? lastWatchedAt,
                ratingValue: res.rating ?? (rating > 0 ? rating * 2 : nil)
            )
            if watchlisted {
                try? await DiaryService.removeMovieWatchlist(id: idString)
                watchlisted = false
            }
        } catch {
            watchCount = previousCount
            watched = previousCount > 0
            lastWatchedAt = previousWatchedAt
        }
    }

    private func performUnwatch(_ detail: MovieDetail, mode: String) async {
        busy = true
        defer { busy = false }
        let previousCount = watchCount
        let previousWatched = watched
        let previousWatchedAt = lastWatchedAt
        let previousRating = rating
        if mode == "all" {
            watched = false
            watchCount = 0
            lastWatchedAt = nil
            rating = 0
        } else {
            watchCount = max(0, previousCount - 1)
            watched = watchCount > 0
            if !watched {
                lastWatchedAt = nil
                rating = 0
            }
        }
        Haptics.light()
        do {
            let res = try await DiaryService.removeMovieWatched(id: idString, mode: mode)
            applyWatchedSummary(
                watched: res.watched,
                count: res.watchCount,
                watchedAt: res.watchedAt,
                ratingValue: res.rating
            )
        } catch {
            watchCount = previousCount
            watched = previousWatched
            lastWatchedAt = previousWatchedAt
            rating = previousRating
        }
    }

    private func toggleWatchlist(_ detail: MovieDetail) async {
        busy = true
        defer { busy = false }
        do {
            if watchlisted {
                try await DiaryService.removeMovieWatchlist(id: idString)
                watchlisted = false
            } else {
                try await DiaryService.addMovieWatchlist(bodyPayload(detail))
                watchlisted = true
            }
            Haptics.light()
        } catch {}
    }
}
