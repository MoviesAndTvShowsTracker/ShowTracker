import SwiftUI

struct MovieDetailView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let movieId: Int

    @State private var detail: MovieDetail?
    @State private var favorited = false
    @State private var watched = false
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
    @State private var showUnwatchConfirm = false
    @State private var showRatingSheet = false

    private enum LoadPhase { case loading, ready, failed(String) }
    private var idString: String { String(movieId) }

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
        .marqueeCanvas()
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .background(EnableSwipeBack())
        .confirmationDialog("Unmark as watched?", isPresented: $showUnwatchConfirm, titleVisibility: .visible) {
            Button("Remove from watched", role: .destructive) {
                Task { if let detail { await performUnwatch(detail) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove \"\(detail?.displayTitle ?? "this film")\" from your watched films?")
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
                subtitle: watched ? "Logged" : nil,
                active: watched
            ) {
                if watched {
                    showUnwatchConfirm = true
                } else {
                    Task { await performWatch(detail) }
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
        let writers = crew.filter { ["Writer", "Screenplay", "Story"].contains($0.job ?? "") }.compactMap(\.name)
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
            rows.append(CreditRow(label: "Writing", value: CreditRow.joinedNames(writers, limit: 4)))
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
                watched = watchedRes.watched ?? false
                if let r = watchedRes.rating {
                    rating = min(5, r > 5 ? r / 2 : r)
                }
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

    private func performWatch(_ detail: MovieDetail) async {
        busy = true
        defer { busy = false }
        watched = true
        Haptics.success()
        do {
            try await DiaryService.addMovieWatched(bodyPayload(detail))
            if watchlisted {
                try? await DiaryService.removeMovieWatchlist(id: idString)
                watchlisted = false
            }
        } catch {
            watched = false
        }
    }

    private func performUnwatch(_ detail: MovieDetail) async {
        busy = true
        defer { busy = false }
        watched = false
        rating = 0
        Haptics.light()
        do {
            try await DiaryService.removeMovieWatched(id: idString)
        } catch {
            watched = true
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
