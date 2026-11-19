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
    @State private var providers: [WatchProvider] = []
    @State private var providerRegion: String?
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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DetailHero(path: detail.backdrop_path ?? detail.poster_path)
                VStack(alignment: .leading, spacing: 22) {
                    mobileHeader(detail)

                    if diaryReady {
                        diarySection(detail)
                    } else {
                        HStack(spacing: 10) {
                            SkeletonBlock(height: 44, radius: 22)
                            SkeletonBlock(height: 44, radius: 22)
                            SkeletonBlock(height: 44, radius: 22)
                        }
                    }

                    WatchProvidersRow(providers: providers, region: providerRegion)

                    if let overview = detail.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionKicker(text: "Synopsis")
                            ExpandableText(text: overview)
                        }
                    }

                    metaGrid(detail)
                    crewSection(detail)
                    castSection(detail)

                    if let similar = detail.similar?.results, !similar.isEmpty {
                        NavigationRail(title: "More like this", items: similar, kind: .movie)
                            .padding(.horizontal, -20)
                    }
                }
                .padding(20)
                .padding(.bottom, 72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .top) {
            HStack {
                GlassBackButton { dismiss() }
                Spacer()
                ShareLink(item: shareText(for: detail)) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.olive)
                        .frame(width: 40, height: 40)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .safeAreaPadding(.top)
        }
    }

    private func shareText(for detail: MovieDetail) -> String {
        var parts = [detail.displayTitle]
        if let year = detail.year { parts.append("(\(year))") }
        parts.append("— logged on Marquee")
        return parts.joined(separator: " ")
    }

    private func mobileHeader(_ detail: MovieDetail) -> some View {
        HStack(alignment: .bottom, spacing: 14) {
            CachedAsyncImage(url: AppConfig.posterURL(path: detail.poster_path))
                .frame(width: 96, height: 144)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: theme.olive.opacity(0.25), radius: 12, y: 6)
                .offset(y: -28)
                .padding(.bottom, -28)

            VStack(alignment: .leading, spacing: 8) {
                Text(detail.displayTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    if let year = detail.year { OliveChip(text: year) }
                    if let runtime = detail.runtime { OliveChip(text: "\(runtime)m") }
                    if let vote = detail.vote_average {
                        Label(String(format: "%.1f", vote), systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func diarySection(_ detail: MovieDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Your diary", accented: true)
            HStack(spacing: 8) {
                ActionStripButton(
                    title: favorited ? "Favorited" : "Favorite",
                    systemImage: favorited ? "heart.fill" : "heart",
                    active: favorited
                ) { Task { await toggleFavorite(detail) } }

                ActionStripButton(
                    title: watched ? "Watched" : "Watched",
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

            if watched {
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
                    .padding(14)
                    .background(theme.oliveSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
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

    private func metaGrid(_ detail: MovieDetail) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            if let year = detail.year { MetaCell(label: "Released", value: year) }
            if let runtime = detail.runtime { MetaCell(label: "Runtime", value: "\(runtime) min") }
            if let vote = detail.vote_average {
                MetaCell(label: "TMDB", value: String(format: "%.1f / 10", vote))
            }
            if let genres = detail.genres, !genres.isEmpty {
                MetaCell(label: "Genres", value: genres.prefix(3).map(\.name).joined(separator: ", "))
            }
        }
    }

    private func crewSection(_ detail: MovieDetail) -> some View {
        let crew = detail.credits?.crew ?? []
        let directors = crew.filter { $0.job == "Director" }.compactMap(\.name)
        let writers = crew.filter { ["Writer", "Screenplay", "Story"].contains($0.job ?? "") }.compactMap(\.name)
        return Group {
            if !directors.isEmpty || !writers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionKicker(text: "Credits")
                    if !directors.isEmpty {
                        MetaCell(label: "Director", value: Array(Set(directors)).prefix(3).joined(separator: ", "))
                    }
                    if !writers.isEmpty {
                        MetaCell(label: "Writing", value: Array(Set(writers)).prefix(4).joined(separator: ", "))
                    }
                }
            }
        }
    }

    private func castSection(_ detail: MovieDetail) -> some View {
        Group {
            if let cast = detail.credits?.cast, !cast.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Cast")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.ink)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(Array(cast.prefix(16))) { member in
                                CastBubble(
                                    name: member.name ?? "",
                                    character: member.character,
                                    profilePath: member.profile_path
                                )
                            }
                        }
                    }
                }
            }
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
            async let providersTask = WatchProviderService.load(kind: .movie, id: movieId)
            detail = try await detailTask
            let loadedProviders = await providersTask
            providers = loadedProviders.providers
            providerRegion = loadedProviders.region
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
