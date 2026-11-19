import SwiftUI

struct TVDetailView: View {
    @Environment(\.marqueeTheme) var theme
    @Environment(\.dismiss) private var dismiss
    let tvId: Int

    @State var detail: TVDetail?
    @State var favorited = false
    @State var watchlisted = false
    @State var tracking: TrackingRecord?
    @State var watchedKeys: Set<String> = []
    @State var selectedSeason = 1
    @State var episodes: [TVEpisode] = []
    @State var seasonLoading = false
    @State var diaryReady = false
    @State var showRating: Double = 0
    @State var providers: [WatchProvider] = []
    @State var providerRegion: String?
    @State var phase: LoadPhase = .loading
    @State var busy = false
    @State var episodePendingUnmark: TVEpisode?
    @State var showUnmarkConfirm = false
    @State var showRatingSheet = false
    @State var episodeIndex: [TVEpisode] = []
    @State var batching = false
    @State var pendingBatch: BatchAction?
    @State var showBatchConfirm = false
    @State var episodePendingRate: TVEpisode?
    @State var episodeRating: Double = 0
    @State var showEpisodeRatingSheet = false
    @State var episodeRatings: [String: Double] = [:]

    enum BatchAction: Equatable {
        case markSeason(season: Int, count: Int)
        case unmarkSeason(season: Int, count: Int)
        case markShow(count: Int)

        var title: String {
            switch self {
            case .markSeason: return "Mark this season?"
            case .unmarkSeason: return "Unmark this season?"
            case .markShow: return "Mark the whole show?"
            }
        }

        var message: String {
            switch self {
            case .markSeason(_, let count):
                return "\(count) released episode\(count == 1 ? "" : "s") in this season will be marked watched."
            case .unmarkSeason(_, let count):
                return "\(count) episode\(count == 1 ? "" : "s") in this season will be unmarked."
            case .markShow(let count):
                return "\(count) released episode\(count == 1 ? "" : "s") across every season will be marked watched."
            }
        }

        var confirmLabel: String {
            switch self {
            case .unmarkSeason: return "Unmark season"
            case .markSeason, .markShow: return "Mark watched"
            }
        }

        var isDestructive: Bool {
            if case .unmarkSeason = self { return true }
            return false
        }
    }

    enum LoadPhase { case loading, ready, failed(String) }
    var idString: String { String(tvId) }
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
        .alert(
            "Unmark episode?",
            isPresented: $showUnmarkConfirm,
            presenting: episodePendingUnmark
        ) { ep in
            Button("Unmark", role: .destructive) {
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
        .sheet(isPresented: $showEpisodeRatingSheet) {
            episodeRatingSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .alert(
            pendingBatch?.title ?? "Confirm",
            isPresented: $showBatchConfirm,
            presenting: pendingBatch
        ) { action in
            Button(action.confirmLabel, role: action.isDestructive ? .destructive : nil) {
                Task { await performBatch(action) }
            }
            Button("Cancel", role: .cancel) {
                pendingBatch = nil
            }
        } message: { action in
            Text(action.message)
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
                    crewSection(detail)
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

    private func shareText(for detail: TVDetail) -> String {
        var parts = [detail.displayTitle]
        if let seasons = detail.number_of_seasons { parts.append("· \(seasons) seasons") }
        parts.append("— tracked on Marquee")
        return parts.joined(separator: " ")
    }

    private func crewSection(_ detail: TVDetail) -> some View {
        let crew = detail.credits?.crew ?? []
        let creators = crew.filter { ["Creator", "Executive Producer", "Director"].contains($0.job ?? "") }.compactMap(\.name)
        let writers = crew.filter { ["Writer", "Screenplay", "Story", "Teleplay"].contains($0.job ?? "") }.compactMap(\.name)
        return Group {
            if !creators.isEmpty || !writers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionKicker(text: "Credits")
                    if !creators.isEmpty {
                        MetaCell(label: "Creators", value: Array(Set(creators)).prefix(3).joined(separator: ", "))
                    }
                    if !writers.isEmpty {
                        MetaCell(label: "Writing", value: Array(Set(writers)).prefix(4).joined(separator: ", "))
                    }
                }
            }
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

    func showProgress(detail: TVDetail?, tracking: TrackingRecord?) -> ShowProgress {
        ShowProgress.nextInSeason(
            track: tracking,
            season: selectedSeason,
            episodes: episodes,
            watchedKeys: watchedKeys,
            catalogTotal: detail?.number_of_episodes
        )
    }

    func formatDate(_ raw: String?) -> String? {
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
            let docs = (try? await epsTask) ?? []
            watchedKeys = Set(docs.compactMap { doc in
                guard let s = doc.seasonNumber, let e = doc.episodeNumber else { return nil }
                return "\(s)-\(e)"
            })
            episodeRatings = Dictionary(uniqueKeysWithValues: docs.compactMap { doc in
                guard let s = doc.seasonNumber, let e = doc.episodeNumber, let rating = doc.rating else { return nil }
                return ("\(s)-\(e)", rating)
            })

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

    func loadSeason() async {
        seasonLoading = true
        defer { seasonLoading = false }
        if let season = try? await TMDBService.season(tvId: tvId, season: selectedSeason) {
            episodes = season.episodes ?? []
        }
    }

    func performMark(_ ep: TVEpisode) async {
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

    var watchedInSeason: [TVEpisode] {
        episodes.filter { watchedKeys.contains($0.diaryKey) }
    }

    var unwatchedAiredAll: [TVEpisode] {
        let catalog = episodeIndex.isEmpty ? episodes : episodeIndex
        return catalog.filter { $0.hasAired && !watchedKeys.contains($0.diaryKey) }
    }

    var canMarkWholeShow: Bool {
        if tracking?.status == "completed" { return false }
        if episodeIndex.isEmpty { return true }
        return !unwatchedAiredAll.isEmpty
    }

    func confirmMarkShow() async {
        guard !batching else { return }
        if episodeIndex.isEmpty, let detail {
            batching = true
            episodeIndex = await fetchEpisodeIndex(from: detail)
            batching = false
        }
        let count = unwatchedAiredAll.count
        guard count > 0 else { return }
        pendingBatch = .markShow(count: count)
        showBatchConfirm = true
    }

    private func performBatch(_ action: BatchAction) async {
        pendingBatch = nil
        guard let detail, !batching else { return }
        batching = true
        defer { batching = false }

        let catalog = episodeIndex.isEmpty ? episodes : episodeIndex
        let targets: [TVEpisode]
        let marking: Bool
        switch action {
        case .markSeason:
            targets = episodes.filter { $0.hasAired && !watchedKeys.contains($0.diaryKey) }
            marking = true
        case .unmarkSeason:
            targets = watchedInSeason
            marking = false
        case .markShow:
            targets = catalog.filter { $0.hasAired && !watchedKeys.contains($0.diaryKey) }
            marking = true
        }
        guard !targets.isEmpty else { return }

        var keys = watchedKeys
        for ep in targets {
            if marking { keys.insert(ep.diaryKey) } else { keys.remove(ep.diaryKey) }
        }
        watchedKeys = keys
        if marking { Haptics.medium() } else { Haptics.light() }

        do {
            let body = batchBody(targets, keys: keys, catalog: catalog, detail: detail)
            let response = marking
                ? try await DiaryService.markBatch(body)
                : try await DiaryService.unmarkBatch(body)
            applyBatch(response)
            if marking, tracking?.status == "completed" {
                Haptics.success()
            }
        } catch {
            if marking {
                for ep in targets { watchedKeys.remove(ep.diaryKey) }
            } else {
                for ep in targets { watchedKeys.insert(ep.diaryKey) }
            }
        }
    }

    private func batchBody(
        _ targets: [TVEpisode],
        keys: Set<String>,
        catalog: [TVEpisode],
        detail: TVDetail
    ) -> BatchEpisodesBody {
        let next = catalog
            .sorted {
                let ls = $0.season_number ?? 0
                let rs = $1.season_number ?? 0
                return ls == rs ? $0.episode_number < $1.episode_number : ls < rs
            }
            .first { $0.hasAired && !keys.contains($0.diaryKey) }
        let airedCount = catalog.filter(\.hasAired).count
        return BatchEpisodesBody(
            tvId: idString,
            episodes: targets.map {
                EpisodeRef(
                    seasonNumber: $0.season_number ?? selectedSeason,
                    episodeNumber: $0.episode_number,
                    runtimeMinutes: $0.runtime,
                    episodeName: $0.name,
                    tmdbEpisodeId: String($0.id)
                )
            },
            tvTitle: detail.name,
            tvPosterImage: detail.poster_path,
            tvBackdropImage: detail.backdrop_path,
            totalEpisodes: detail.number_of_episodes ?? catalog.count,
            airedEpisodeCount: airedCount > 0 ? airedCount : detail.number_of_episodes,
            nextSeason: next?.season_number,
            nextEpisode: next?.episode_number,
            nextEpisodeName: next?.name
        )
    }

    private func applyBatch(_ response: EpisodeBatchResponse) {
        if let docs = response.episodes {
            watchedKeys = Set(docs.compactMap { doc in
                guard let s = doc.seasonNumber, let e = doc.episodeNumber else { return nil }
                return "\(s)-\(e)"
            })
        }
        if let tracking = response.tracking {
            self.tracking = tracking
        }
    }

    private func fetchEpisodeIndex(from detail: TVDetail) async -> [TVEpisode] {
        let seasons = (detail.seasons ?? [])
            .filter { $0.season_number > 0 }
            .sorted { $0.season_number < $1.season_number }
        guard !seasons.isEmpty else { return episodes }
        return await withTaskGroup(of: (Int, [TVEpisode]).self) { group in
            for season in seasons {
                group.addTask {
                    let loaded = try? await TMDBService.season(tvId: tvId, season: season.season_number)
                    return (season.season_number, loaded?.episodes ?? [])
                }
            }
            var bySeason: [Int: [TVEpisode]] = [:]
            for await pair in group {
                bySeason[pair.0] = pair.1
            }
            return seasons.flatMap { bySeason[$0.season_number] ?? [] }
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
