import SwiftUI

struct TVDetailView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    let tvId: Int

    @State private var detail: TVDetail?
    @State private var favorited = false
    @State private var watchlisted = false
    @State private var tracking: TrackingRecord?
    @State private var watchedKeys: Set<String> = []
    @State private var selectedSeason = 1
    @State private var episodes: [TVEpisode] = []
    @State private var seasonLoading = false
    @State private var diaryReady = false
    @State private var showRating: Double = 0
    @State private var providers: [WatchProvider] = []
    @State private var providerRegion: String?
    @State private var phase: LoadPhase = .loading
    @State private var busy = false
    @State private var episodePendingUnmark: TVEpisode?
    @State private var showUnmarkConfirm = false
    @State private var showRatingSheet = false

    private enum LoadPhase { case loading, ready, failed(String) }
    private var idString: String { String(tvId) }
    private var isTracking: Bool {
        guard let status = tracking?.status else { return false }
        return status == "watching" || status == "paused" || status == "completed"
    }

    var body: some View {
        Group {
            switch phase {
            case .loading:
                DetailPageSkeleton()
            case .failed(let message):
                ContentUnavailableView(
                    "Couldn’t load",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .ready:
                if let detail { content(detail) }
            }
        }
        .marqueeCanvas()
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .background(EnableSwipeBack())
        .confirmationDialog(
            "Unmark episode?",
            isPresented: $showUnmarkConfirm,
            titleVisibility: .visible,
            presenting: episodePendingUnmark
        ) { ep in
            Button("Unmark watched", role: .destructive) {
                Task { await performUnmark(ep) }
            }
            Button("Cancel", role: .cancel) {
                episodePendingUnmark = nil
            }
        } message: { ep in
            let s = ep.season_number ?? selectedSeason
            Text("Unmark S\(s) E\(ep.episode_number)\(ep.name.map { " — \($0)" } ?? "") as watched?")
        }
        .sheet(isPresented: $showRatingSheet) {
            ratingSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .task { await load() }
    }

    private func content(_ detail: TVDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                DetailHero(path: detail.backdrop_path ?? detail.poster_path)
                VStack(alignment: .leading, spacing: 22) {
                    header(detail)

                    if !diaryReady {
                        diarySkeleton
                    } else {
                        trackingBlock(detail)
                        diaryActions(detail)
                    }

                    WatchProvidersRow(providers: providers, region: providerRegion)

                    if let overview = detail.overview, !overview.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionKicker(text: "Synopsis")
                            ExpandableText(text: overview)
                        }
                    }

                    metaGrid(detail)
                    castSection(detail)
                    episodesBlock(detail)

                    if let similar = detail.similar?.results, !similar.isEmpty {
                        NavigationRail(title: "More like this", items: similar, kind: .tv)
                            .padding(.horizontal, -20)
                    }
                }
                .padding(20)
                .padding(.bottom, 72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .topLeading) {
            GlassBackButton { dismiss() }
                .padding(.leading, 16)
                .padding(.top, 10)
                .safeAreaPadding(.top)
        }
    }

    private func header(_ detail: TVDetail) -> some View {
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
                    if let seasons = detail.number_of_seasons {
                        OliveChip(text: "\(seasons) season\(seasons == 1 ? "" : "s")")
                    }
                    if let vote = detail.vote_average {
                        Label(String(format: "%.1f", vote), systemImage: "star.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.accent)
                    }
                }
                if let air = formatDate(detail.first_air_date) {
                    Text(air)
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var diarySkeleton: some View {
        VStack(spacing: 12) {
            SkeletonBlock(height: 120, radius: 18)
            HStack(spacing: 10) {
                SkeletonBlock(height: 72, radius: 14)
                SkeletonBlock(height: 72, radius: 14)
            }
        }
    }

    @ViewBuilder
    private func trackingBlock(_ detail: TVDetail) -> some View {
        if let tracking {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        OliveChip(text: tracking.status?.capitalized ?? "Tracking")
                        Spacer()
                        if tracking.status == "watching" {
                            Button("Pause") { Task { await pause() } }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.inkMuted)
                        } else if tracking.status == "paused" {
                            Button("Resume") { Task { await resume() } }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.accent)
                        }
                    }

                    let progress = showProgress(detail: detail, tracking: tracking)
                    Text(progress.episodeLine)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                    Text(progress.next?.name ?? tracking.nextEpisodeName ?? "Up next")
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)

                    HStack {
                        ProgressTrack(
                            progress: progress.fraction,
                            completed: progress.isComplete
                        )
                        if progress.total > 0 {
                            Text("\(progress.percent)%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.olive)
                                .monospacedDigit()
                        }
                    }

                    Text(progress.caption)
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)

                    if tracking.status == "watching" {
                        NavigationLink {
                            TVContinueView(tvId: tvId, seed: tracking)
                        } label: {
                            Text("Continue watching")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.onAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(theme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            Button {
                Task { await startTracking(detail) }
            } label: {
                Label("Start tracking this show", systemImage: "play.circle.fill")
                    .font(.headline)
                    .foregroundStyle(theme.olive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.oliveSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func diaryActions(_ detail: TVDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Your diary", accented: true)
            HStack(spacing: 8) {
                ActionStripButton(
                    title: favorited ? "Favorited" : "Favorite",
                    systemImage: favorited ? "heart.fill" : "heart",
                    active: favorited
                ) { Task { await toggleFavorite(detail) } }

                // Web pattern: status replaces watchlist once tracking
                if let status = tracking?.status, status != "dropped" {
                    statusChip(status)
                } else {
                    ActionStripButton(
                        title: watchlisted ? "On list" : "Watchlist",
                        systemImage: watchlisted ? "bookmark.fill" : "bookmark",
                        active: watchlisted
                    ) { Task { await toggleWatchlist(detail) } }
                }
                Spacer(minLength: 0)
            }
            .disabled(busy)

            if (tracking?.watchedEpisodeCount ?? 0) > 0 {
                Button {
                    showRatingSheet = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Show rating")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(theme.ink)
                            if showRating > 0 {
                                StarRatingView(rating: $showRating, editable: false, size: .body)
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

    private func statusChip(_ status: String) -> some View {
        let label: String
        let icon: String
        switch status {
        case "completed": label = "Completed"; icon = "checkmark.circle.fill"
        case "paused": label = "Paused"; icon = "pause.circle.fill"
        default: label = "Watching"; icon = "play.circle.fill"
        }
        return NavigationLink {
            TVContinueView(tvId: tvId, seed: tracking)
        } label: {
            DiaryChipLabel(title: label, systemImage: icon, active: true)
        }
        .buttonStyle(PressablePosterStyle())
        .fixedSize()
    }

    private var ratingSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(detail?.displayTitle ?? "Show")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.ink)
                Text("How was it overall?")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                StarRatingView(rating: $showRating, size: .largeTitle)
                    .frame(maxWidth: .infinity)
                if showRating > 0 {
                    Text("\(Int(showRating)) of 5 stars")
                        .font(.headline)
                        .foregroundStyle(theme.olive)
                        .frame(maxWidth: .infinity)
                }
                Spacer()
                Button("Save rating") {
                    Task {
                        try? await DiaryService.rateShow(tvId: idString, rating: max(1, showRating * 2))
                        showRatingSheet = false
                        Haptics.success()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(showRating <= 0)
            }
            .padding(24)
            .marqueeCanvas()
            .navigationTitle("Rate show")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showRatingSheet = false }
                }
            }
        }
    }

    private func metaGrid(_ detail: TVDetail) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            if let air = formatDate(detail.first_air_date) {
                MetaCell(label: "Premiered", value: air)
            }
            if let status = detail.status {
                MetaCell(label: "Status", value: status)
            }
            if let seasons = detail.number_of_seasons {
                MetaCell(label: "Seasons", value: "\(seasons)")
            }
            if let eps = detail.number_of_episodes {
                MetaCell(label: "Episodes", value: "\(eps)")
            }
            if let runtime = detail.typicalRuntime {
                MetaCell(label: "Runtime", value: "\(runtime) min")
            }
            if let networks = detail.networkNames {
                MetaCell(label: "Network", value: networks)
            }
            if let genres = detail.genres, !genres.isEmpty {
                MetaCell(label: "Genres", value: genres.prefix(3).map(\.name).joined(separator: ", "))
            }
            if let vote = detail.vote_average {
                MetaCell(label: "TMDB", value: String(format: "%.1f / 10", vote))
            }
        }
    }

    private func castSection(_ detail: TVDetail) -> some View {
        Group {
            if let cast = detail.credits?.cast, !cast.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Cast")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.ink)
                        Text("\(min(cast.count, 16))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.olive)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(theme.oliveSoft)
                            .clipShape(Capsule())
                    }

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

    private func episodesBlock(_ detail: TVDetail) -> some View {
        let seasons = (detail.seasons ?? []).filter { $0.season_number > 0 }
        return VStack(alignment: .leading, spacing: 14) {
            SectionKicker(text: "Episodes")
            Text("Mark as you go")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.ink)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(seasons) { season in
                        Button {
                            selectedSeason = season.season_number
                            Task { await loadSeason() }
                        } label: {
                            Text(season.name ?? "S\(season.season_number)")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .foregroundStyle(selectedSeason == season.season_number ? theme.onAccent : theme.olive)
                                .background(selectedSeason == season.season_number ? theme.olive : theme.oliveSoft)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            GlassCard(padding: 0) {
                Group {
                    if seasonLoading {
                        VStack(spacing: 0) {
                            ForEach(0..<4, id: \.self) { _ in
                                SkeletonBlock(height: 72, radius: 0)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(episodes) { ep in
                                episodeRow(ep)
                                Divider().overlay(theme.border).padding(.leading, 56)
                            }
                        }
                    }
                }
            }
        }
    }

    private func episodeRow(_ ep: TVEpisode) -> some View {
        let season = ep.season_number ?? selectedSeason
        let key = "\(season)-\(ep.episode_number)"
        let marked = watchedKeys.contains(key)
        let isNext = showProgress(detail: detail, tracking: tracking).next.map {
            $0.season == season && $0.episode == ep.episode_number
        } ?? false

        return Button {
            if marked {
                episodePendingUnmark = ep
                showUnmarkConfirm = true
            } else {
                Task { await performMark(ep) }
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: marked ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(marked ? theme.accent : theme.olive.opacity(0.45))
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("E\(ep.episode_number) · \(ep.name ?? "Episode")")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if isNext {
                            Text("Up next")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(theme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.accent.opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        if let air = formatDate(ep.air_date) {
                            Text(air)
                                .font(.caption)
                                .foregroundStyle(theme.inkMuted)
                        }
                        if let runtime = ep.runtime, runtime > 0 {
                            Text("\(runtime) min")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.olive)
                        }
                    }

                    if let overview = ep.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.caption)
                            .foregroundStyle(theme.inkMuted)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 72, alignment: .top)
            .background(isNext ? theme.accent.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Progress helpers

    private func markBody(for ep: TVEpisode, afterMark: Bool) -> MarkEpisodeBody {
        let season = ep.season_number ?? selectedSeason
        var keys = watchedKeys
        let key = "\(season)-\(ep.episode_number)"
        if afterMark { keys.insert(key) } else { keys.remove(key) }

        let later = episodes.first { candidate in
            let s = candidate.season_number ?? selectedSeason
            return !keys.contains("\(s)-\(candidate.episode_number)")
                && (s > season || (s == season && candidate.episode_number > ep.episode_number))
        }
        let nextSeason = later?.season_number ?? (later == nil ? season + 1 : season)
        let nextEpisode = later?.episode_number ?? 1
        let total = detail?.number_of_episodes

        return MarkEpisodeBody(
            tvId: idString,
            seasonNumber: season,
            episodeNumber: ep.episode_number,
            runtimeMinutes: ep.runtime,
            episodeName: ep.name,
            tvTitle: detail?.name,
            tvPosterImage: detail?.poster_path,
            totalEpisodes: total,
            airedEpisodeCount: total,
            nextSeason: nextSeason,
            nextEpisode: nextEpisode,
            nextEpisodeName: later?.name
        )
    }

    private func showProgress(detail: TVDetail?, tracking: TrackingRecord?) -> ShowProgress {
        ShowProgress.nextInSeason(
            track: tracking,
            season: selectedSeason,
            episodes: episodes,
            watchedKeys: watchedKeys,
            catalogTotal: detail?.number_of_episodes
        )
    }

    private func formatDate(_ raw: String?) -> String? {
        guard let raw, raw.count >= 10 else { return nil }
        let parts = raw.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else {
            return String(raw.prefix(10))
        }
        var comps = DateComponents()
        comps.year = y; comps.month = m; comps.day = d
        guard let date = Calendar.current.date(from: comps) else { return String(raw.prefix(10)) }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    // MARK: - Data

    private func load() async {
        phase = .loading
        diaryReady = false
        do {
            // Fetch show + diary together so status isn’t a late flash
            async let detailTask = TMDBService.tvDetail(id: tvId)
            async let favTask = DiaryService.tvFavorited(id: idString)
            async let listTask = DiaryService.tvWatchlisted(id: idString)
            async let trackTask = DiaryService.tracking(for: idString)
            async let epsTask = DiaryService.watchedEpisodes(tvId: idString)
            async let providersTask = WatchProviderService.load(kind: .tv, id: tvId)

            let loaded = try await detailTask
            detail = loaded
            let loadedProviders = await providersTask
            providers = loadedProviders.providers
            providerRegion = loadedProviders.region

            favorited = (try? await favTask) ?? false
            watchlisted = (try? await listTask) ?? false
            tracking = try? await trackTask
            if let r = tracking?.rating { showRating = min(5, r / 2) }
            watchedKeys = Set((try? await epsTask)?.compactMap { doc in
                guard let s = doc.seasonNumber, let e = doc.episodeNumber else { return nil }
                return "\(s)-\(e)"
            } ?? [])

            let firstSeason = loaded.seasons?.first(where: { $0.season_number > 0 })?.season_number ?? 1
            if let next = tracking?.nextSeason,
               loaded.seasons?.contains(where: { $0.season_number == next }) == true {
                selectedSeason = next
            } else {
                selectedSeason = firstSeason
            }

            diaryReady = true
            phase = .ready
            await loadSeason()
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func loadSeason() async {
        seasonLoading = true
        defer { seasonLoading = false }
        if let season = try? await TMDBService.season(tvId: tvId, season: selectedSeason) {
            episodes = season.episodes ?? []
        }
    }

    private func performMark(_ ep: TVEpisode) async {
        let season = ep.season_number ?? selectedSeason
        let key = "\(season)-\(ep.episode_number)"
        // Optimistic tick — feel instant
        watchedKeys.insert(key)
        Haptics.medium()
        let body = markBody(for: ep, afterMark: true)
        do {
            try await DiaryService.markEpisode(body)
            if tracking == nil, let detail {
                try? await DiaryService.startTracking(
                    TrackingStartBody(tvId: idString, tvTitle: detail.name, tvPosterImage: detail.poster_path)
                )
            }
            tracking = try? await DiaryService.tracking(for: idString)
        } catch {
            watchedKeys.remove(key)
        }
    }

    private func performUnmark(_ ep: TVEpisode) async {
        let season = ep.season_number ?? selectedSeason
        let key = "\(season)-\(ep.episode_number)"
        watchedKeys.remove(key)
        Haptics.light()
        episodePendingUnmark = nil
        let body = markBody(for: ep, afterMark: false)
        do {
            try await DiaryService.unmarkEpisode(body)
            tracking = try? await DiaryService.tracking(for: idString)
        } catch {
            watchedKeys.insert(key)
        }
    }

    private func toggleFavorite(_ detail: TVDetail) async {
        busy = true
        defer { busy = false }
        let body = TVIdBody(tvId: idString, tvTitle: detail.name, tvPosterImage: detail.poster_path)
        do {
            if favorited {
                try await DiaryService.removeTVFavorite(id: idString)
                favorited = false
            } else {
                try await DiaryService.addTVFavorite(body)
                favorited = true
            }
            Haptics.light()
        } catch {}
    }

    private func toggleWatchlist(_ detail: TVDetail) async {
        busy = true
        defer { busy = false }
        let body = TVIdBody(tvId: idString, tvTitle: detail.name, tvPosterImage: detail.poster_path)
        do {
            if watchlisted {
                try await DiaryService.removeTVWatchlist(id: idString)
                watchlisted = false
            } else {
                try await DiaryService.addTVWatchlist(body)
                watchlisted = true
            }
            Haptics.light()
        } catch {}
    }

    private func startTracking(_ detail: TVDetail) async {
        do {
            try await DiaryService.startTracking(
                TrackingStartBody(tvId: idString, tvTitle: detail.name, tvPosterImage: detail.poster_path)
            )
            tracking = try await DiaryService.tracking(for: idString)
            watchlisted = false
            Haptics.success()
        } catch {}
    }

    private func pause() async {
        try? await DiaryService.stopTracking(tvId: idString, status: "paused")
        tracking = try? await DiaryService.tracking(for: idString)
    }

    private func resume() async {
        try? await DiaryService.resumeTracking(tvId: idString)
        tracking = try? await DiaryService.tracking(for: idString)
    }
}
