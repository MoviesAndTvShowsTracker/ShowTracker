import SwiftUI

struct TVDetailView: View {
    @Environment(\.marqueeTheme) var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var preferences
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
    @State var ratings: MediaRatings?
    @State var ratingsReady = false
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
    @State private var loadGeneration = 0
    @State private var seasonLoadGeneration = 0
    @State private var pane: TVDetailPane = .info
    @State private var didApplyPreferredPane = false
    @State private var providersReady = false
    @State private var paneRevealToken = 0
    @State var rewatchSession: RewatchSessionDoc?
    @State var showStartRewatchConfirm = false
    @State var showCancelRewatchConfirm = false
    @State var showSeasonActionConfirm = false
    /// "S-E" → total plays (first watch + rewatches).
    @State var episodePlayCounts: [String: Int] = [:]
    /// "S-E" → ISO watch dates, oldest → newest.
    @State var episodePlayDates: [String: [String]] = [:]
    @State var rewatchPlayTotal: Int = 0

    /// Notes on logged episodes, by "season-episode".
    @State var episodeNotes: [String: String] = [:]
    /// When each episode was first logged (the canonical watch, not rewatches).
    @State var episodeWatchedAt: [String: Date] = [:]
    /// The log sheet for an episode: log with a date and note, or edit one.
    @State var episodeLogTarget: EpisodeLogTarget?

    enum BatchAction: Equatable {
        case markSeason(season: Int, count: Int)
        case unmarkSeason(season: Int, count: Int)
        case markShow(count: Int)
        case markUpTo(season: Int, episode: Int, count: Int)

        var title: String {
            switch self {
            case .markSeason: return "Mark this season?"
            case .unmarkSeason: return "Unmark this season?"
            case .markShow: return "Mark the whole show?"
            case .markUpTo: return "Mark watched up to here?"
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
            case .markUpTo(let season, let episode, let count):
                return "\(count) released episode\(count == 1 ? "" : "s") through S\(season) · E\(episode) will be marked watched."
            }
        }

        var confirmLabel: String {
            switch self {
            case .unmarkSeason: return "Unmark season"
            case .markSeason, .markShow, .markUpTo: return "Mark watched"
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
        return status == "watching" || status == "paused" || status == "completed" || status == "rewatching"
    }

    var isRewatching: Bool { tracking?.status == "rewatching" }

    private var episodeAlertTitle: String {
        guard let ep = episodePendingUnmark else { return "Watched" }
        let plays = playCount(for: ep)
        return plays > 1 ? "Watched \(plays) times" : "Watched"
    }

    private func episodeRemoveLabel(for ep: TVEpisode) -> String {
        playCount(for: ep) > 1 ? "Remove latest watch" : "Mark as unwatched"
    }

    private func episodeAlertMessage(for ep: TVEpisode) -> String {
        let s = ep.season_number ?? selectedSeason
        let name = ep.name.map { " — \($0)" } ?? ""
        let plays = playCount(for: ep)
        let labels = playDates(for: ep).compactMap(shortWatchDate)

        var lines: [String] = ["S\(s) E\(ep.episode_number)\(name)"]
        if labels.isEmpty {
            lines.append("")
        } else if labels.count == 1 {
            lines.append("")
            lines.append("Watched \(labels[0])")
        } else {
            lines.append("")
            for (index, label) in labels.enumerated() {
                let suffix = index == labels.count - 1 ? " (latest)" : ""
                lines.append("\(index + 1). \(label)\(suffix)")
            }
        }
        lines.append("")
        if plays > 1 {
            lines.append("Watch again, or peel off the latest one.")
        } else {
            lines.append("Watch again, or clear this watch.")
        }
        return lines.joined(separator: "\n")
    }

    private func playCount(for ep: TVEpisode) -> Int {
        let s = ep.season_number ?? selectedSeason
        let key = "\(s)-\(ep.episode_number)"
        return episodePlayCounts[key] ?? (watchedKeys.contains(key) ? 1 : 0)
    }

    private func playDates(for ep: TVEpisode) -> [String] {
        let s = ep.season_number ?? selectedSeason
        let key = "\(s)-\(ep.episode_number)"
        return episodePlayDates[key] ?? []
    }

    func shortWatchDate(_ iso: String?) -> String? {
        guard let iso, iso.count >= 10 else { return nil }
        let day = String(iso.prefix(10))
        let parts = day.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              let date = Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
        else { return nil }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
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
        .marqueeDetailCanvas()
        .navigationBarBackButtonHidden(true)
        .background(EnableSwipeBack())
        .alert(
            episodeAlertTitle,
            isPresented: $showUnmarkConfirm,
            presenting: episodePendingUnmark
        ) { ep in
            Button("Watch again") {
                Task { await performLogRewatch(ep) }
            }
            if !isRewatching && watchedKeys.contains(ep.diaryKey) {
                Button("Edit date & note…") { episodeLogTarget = .edit(ep) }
            }
            Button(episodeRemoveLabel(for: ep), role: .destructive) {
                Task { await performUnmark(ep) }
            }
            Button("Cancel", role: .cancel) {
                episodePendingUnmark = nil
            }
        } message: { ep in
            Text(episodeAlertMessage(for: ep))
        }
        .alert("Season watched", isPresented: $showSeasonActionConfirm) {
            Button("Watch season again") {
                Task { await performSeasonRewatch() }
            }
            Button("Remove season watches", role: .destructive) {
                pendingBatch = .unmarkSeason(season: selectedSeason, count: watchedInSeason.count)
                showBatchConfirm = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Add another watch for every aired episode, or strip watches from this season (latest first).")
        }
        .sheet(isPresented: $showRatingSheet) {
            ratingSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $episodeLogTarget) { target in episodeLogSheet(target) }
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
        .alert("Start a rewatch?", isPresented: $showStartRewatchConfirm) {
            Button("Start rewatch") {
                Task { await performStartRewatch() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your original watch history stays. Episode checks reset for this rewatch only.")
        }
        .alert("Cancel rewatch?", isPresented: $showCancelRewatchConfirm) {
            Button("Cancel rewatch", role: .destructive) {
                Task { await performCancelRewatch() }
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Rewatch progress for this run will be cleared. Your first watch stays intact.")
        }
        .task { await load() }
    }

    private func content(_ detail: TVDetail) -> some View {
        MediaDetailShell(
            backdropPath: detail.backdrop_path ?? detail.poster_path,
            title: detail.displayTitle,
            metaParts: tvMetaParts(detail),
            genresLine: detail.genres?.prefix(3).map(\.name).joined(separator: "  ·  "),
            shareText: shareText(for: detail),
            onBack: { dismiss() },
            actions: {
                if diaryReady {
                    VStack(alignment: .leading, spacing: 14) {
                        trackingBlock(detail)
                        DiaryGlassStrip {
                            diaryActions(detail)
                        }
                    }
                    .animation(reduceMotion ? nil : MarqueeMotion.standard, value: diaryReady)
                } else {
                    TVDetailDiaryChromePlaceholder()
                }
            },
            content: {
                if diaryReady {
                    TVDetailPaneSwitcher(pane: $pane, enabled: true, showsSelection: true)
                    paneBody(detail)
                        .id("\(pane.rawValue)-\(paneRevealToken)")
                        .transition(userPaneTransition)
                } else {
                    TVDetailPaneSwitcher(pane: $pane, enabled: false, showsSelection: false)
                    TVDetailPanePlaceholder()
                }
            }
        )
    }

    private func tvMetaParts(_ detail: TVDetail) -> [String] {
        var year: String?
        if let date = detail.first_air_date, date.count >= 4 {
            year = String(date.prefix(4))
        }
        var extra: [String] = []
        if let seasons = detail.number_of_seasons {
            extra.append("\(seasons) season\(seasons == 1 ? "" : "s")")
        }
        return MediaMetaLine.parts(
            year: year,
            runtimeMinutes: detail.typicalRuntime,
            extra: extra
        )
    }

    /// Only for user tab taps — initial preferred pane is set with zero motion.
    private var userPaneTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .asymmetric(
                insertion: .opacity.combined(with: .offset(y: 6)),
                removal: .opacity
            )
    }

    @ViewBuilder
    private func paneBody(_ detail: TVDetail) -> some View {
        switch pane {
        case .info:
            infoPane(detail)
        case .episodes:
            episodesBlock(detail)
        }
    }

    @ViewBuilder
    private func infoPane(_ detail: TVDetail) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            RatingsStrip(ratings: ratings, isLoading: !ratingsReady)

            WatchProvidersRow(
                providers: providers,
                region: providerRegion,
                isLoading: !providersReady
            )

            if let overview = detail.overview, !overview.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionKicker(text: "Synopsis")
                    ExpandableText(text: overview)
                }
            }

            if !tvFactsLine(detail).isEmpty {
                Text(tvFactsLine(detail))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            CreditsRows(rows: tvCreditRows(detail))
            MediaCastRail(cast: tvCastItems(detail))

            if let similar = detail.similar?.results, !similar.isEmpty {
                NavigationRail(title: "More like this", items: similar, kind: .tv)
                    .padding(.horizontal, -20)
            }
        }
    }

    private func tvFactsLine(_ detail: TVDetail) -> String {
        var parts: [String] = []
        if let status = detail.status { parts.append(status) }
        if let eps = detail.number_of_episodes { parts.append("\(eps) episodes") }
        if let networks = detail.networkNames { parts.append(networks) }
        return parts.joined(separator: "  ·  ")
    }

    private func tvCreditRows(_ detail: TVDetail) -> [CreditRow] {
        let crew = detail.credits?.crew ?? []
        // Prefer Creator / Director for tappable chips; EP alone stays in plain text fallback.
        let leadPeople = CreditRow.uniquePeople(crew, jobs: ["Creator", "Director"], limit: 4)
        let writers = CreditRow.uniquePeople(
            crew,
            jobs: ["Writer", "Screenplay", "Story", "Teleplay"],
            limit: 4
        )
        var rows: [CreditRow] = []
        if !leadPeople.isEmpty {
            rows.append(
                CreditRow(
                    label: leadPeople.count == 1 ? "Creator" : "Creators",
                    value: leadPeople.map(\.name).joined(separator: ", "),
                    people: leadPeople
                )
            )
        } else {
            let eps = CreditRow.uniquePeople(crew, jobs: ["Executive Producer"], limit: 3)
            if !eps.isEmpty {
                rows.append(
                    CreditRow(
                        label: "Creators",
                        value: eps.map(\.name).joined(separator: ", "),
                        people: eps
                    )
                )
            }
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

    private func tvCastItems(_ detail: TVDetail) -> [(id: Int, name: String, character: String?, profilePath: String?)] {
        (detail.credits?.cast ?? []).prefix(16).compactMap { member in
            guard let name = member.name, !name.isEmpty else { return nil }
            return (id: member.id, name: name, character: member.character, profilePath: member.profile_path)
        }
    }

    private func shareText(for detail: TVDetail) -> String {
        var parts = [detail.displayTitle]
        if let seasons = detail.number_of_seasons { parts.append("· \(seasons) seasons") }
        parts.append("— tracked on Marquee")
        return parts.joined(separator: " ")
    }


    @ViewBuilder
    private func trackingBlock(_ detail: TVDetail) -> some View {
        if let tracking {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        OliveChip(text: trackingChipLabel(tracking))
                        Spacer()
                        if tracking.status == "watching" {
                            Button("Pause") { Task { await pause() } }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.inkMuted)
                        } else if tracking.status == "paused" {
                            Button("Resume") { Task { await resume() } }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.accentInk)
                        } else if tracking.status == "rewatching" {
                            Button("Cancel rewatch") { showCancelRewatchConfirm = true }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red.opacity(0.9))
                        } else if tracking.status == "completed" {
                            Button("Start rewatch") { showStartRewatchConfirm = true }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.accentInk)
                        }
                    }

                    let progress = showProgress(detail: detail, tracking: tracking)
                    Text(progress.episodeLine)
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                    if isRewatching || progress.fraction < 1 {
                        Text(
                            isRewatching
                                ? (progress.next?.name ?? tracking.nextEpisodeName ?? "Next episode to rewatch")
                                : (progress.next?.name ?? tracking.nextEpisodeName ?? "Up next")
                        )
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                    }

                    HStack {
                        ProgressTrack(
                            progress: progress.fraction,
                            completed: progress.isComplete && !isRewatching
                        )
                        if progress.total > 0 {
                            Text("\(progress.percent)%")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.olive)
                                .monospacedDigit()
                        }
                    }

                    Text(rewatchCaption(progress: progress, tracking: tracking))
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)

                    if tracking.status == "watching" || tracking.status == "rewatching" {
                        NavigationLink {
                            TVContinueView(tvId: tvId, seed: tracking)
                        } label: {
                            Text(tracking.status == "rewatching" ? "Continue rewatch" : "Continue watching")
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
            // Match web: tracking starts when you mark an episode — don't create a 0-ep Watching row.
            Button {
                withAnimation(reduceMotion ? nil : MarqueeMotion.micro) {
                    pane = .episodes
                }
                Haptics.light()
            } label: {
                Label("Mark an episode to start", systemImage: "checklist")
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
        let subtitle: String?
        switch status {
        case "completed":
            label = "Completed"
            icon = "checkmark.circle.fill"
            let times = tracking?.timesCompleted ?? 1
            subtitle = times > 1 ? "×\(times)" : nil
        case "paused":
            label = "Paused"; icon = "pause.circle.fill"; subtitle = nil
        case "rewatching":
            let n = rewatchSession?.sessionNumber ?? 1
            label = "Rewatch"
            icon = "arrow.clockwise"
            subtitle = "#\(n)"
        default:
            label = "Watching"; icon = "play.circle.fill"; subtitle = nil
        }
        return NavigationLink {
            TVContinueView(tvId: tvId, seed: tracking)
        } label: {
            DiaryChipLabel(title: label, systemImage: icon, subtitle: subtitle, active: true)
        }
        .buttonStyle(PressablePosterStyle())
        .fixedSize()
    }

    private func trackingChipLabel(_ tracking: TrackingRecord) -> String {
        switch tracking.status {
        case "rewatching":
            let n = rewatchSession?.sessionNumber ?? 1
            return "Rewatch #\(n)"
        case "completed":
            let times = tracking.timesCompleted ?? 1
            return times > 1 ? "Completed ×\(times)" : "Completed"
        default:
            return tracking.status?.capitalized ?? "Tracking"
        }
    }

    private func rewatchCaption(progress: ShowProgress, tracking: TrackingRecord) -> String {
        if tracking.status == "rewatching" {
            if progress.total > 0 {
                return "Rewatch \(progress.watched) of \(progress.total) — original history kept"
            }
            return "Rewatch in progress — original history kept"
        }
        if rewatchPlayTotal > 0, tracking.status == "completed" {
            return "\(progress.caption) · \(rewatchPlayTotal) rewatch play\(rewatchPlayTotal == 1 ? "" : "s")"
        }
        return progress.caption
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
                        do {
                            try await DiaryService.rateShow(tvId: idString, rating: showRating)
                            showRatingSheet = false
                            Haptics.success()
                        } catch {
                            Feedback.failed("Couldn't save your rating. Try again.")
                        }
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
        // Only this season's episodes are loaded here; past its end the server picks the next
        // real episode from TMDB, so don't guess "season + 1".
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
            nextSeason: later.map { $0.season_number ?? season },
            nextEpisode: later?.episode_number,
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
        loadGeneration += 1
        let generation = loadGeneration
        phase = .loading
        diaryReady = false
        providersReady = false
        ratingsReady = false
        didApplyPreferredPane = false
        pane = .info
        do {
            // Shell first (hero + title). Diary/providers commit atomically under the fold
            // so the first pane paint is already the right tab with no CLS pops.
            let region = preferences.resolvedWatchRegion
            async let detailTask = TMDBService.tvDetail(id: tvId)
            async let stateTask = DiaryService.tvState(id: idString)
            async let providersTask = WatchProviderService.load(kind: .tv, id: tvId, preferredRegion: region)
            async let ratingsTask = RatingsService.load(kind: .tv, id: tvId)

            let loaded = try await detailTask
            guard generation == loadGeneration else { return }
            detail = loaded
            let firstSeason = loaded.seasons?.first(where: { $0.season_number > 0 })?.season_number ?? 1
            selectedSeason = firstSeason
            seasonLoading = true
            phase = .ready

            async let seasonLoad: Void = loadSeason()

            let userState = try? await stateTask
            let resolvedTrack = userState?.tracking
            let resolvedFav = userState?.favorited ?? false
            let resolvedList = userState?.watchlisted ?? false
            let docs = userState?.episodes ?? []
            let rewatchState = userState?.rewatch
            let loadedProviders = await providersTask
            let loadedRatings = await ratingsTask
            guard generation == loadGeneration else { return }

            favorited = resolvedFav
            watchlisted = resolvedList
            if tracking == nil {
                tracking = rewatchState?.tracking ?? resolvedTrack
            }
            rewatchSession = rewatchState?.activeSession
            // Apply play counts without animation — bulk LazyVStack updates with
            // animated symbol/scale previously SIGSEGV'd AttributeGraph.
            var playTxn = Transaction()
            playTxn.disablesAnimations = true
            withTransaction(playTxn) {
                episodePlayCounts = rewatchState?.playCounts ?? [:]
                episodePlayDates = rewatchState?.playDates ?? [:]
                rewatchPlayTotal = rewatchState?.rewatchPlayTotal ?? 0
            }
            if let track = rewatchState?.tracking {
                tracking = track
            }
            if let r = tracking?.rating { showRating = min(5, r / 2) }

            let activeRewatchDocs = rewatchState?.activeSession?.episodes ?? []
            let keysSource = tracking?.status == "rewatching" ? activeRewatchDocs : docs
            watchedKeys = Set(keysSource.compactMap { doc in
                guard let s = doc.seasonNumber, let e = doc.episodeNumber else { return nil }
                return "\(s)-\(e)"
            })
            episodeRatings = Dictionary(uniqueKeysWithValues: docs.compactMap { doc in
                guard let s = doc.seasonNumber, let e = doc.episodeNumber, let rating = doc.rating else { return nil }
                return ("\(s)-\(e)", rating)
            })
            episodeWatchedAt = Dictionary(uniqueKeysWithValues: docs.compactMap { doc in
                guard let s = doc.seasonNumber, let e = doc.episodeNumber, let at = ISODate.parse(doc.watchedAt) else { return nil }
                return ("\(s)-\(e)", at)
            })
            episodeNotes = Dictionary(uniqueKeysWithValues: docs.compactMap { doc in
                guard let s = doc.seasonNumber, let e = doc.episodeNumber,
                      let note = doc.note.map(DiaryNote.trimmed), !note.isEmpty else { return nil }
                return ("\(s)-\(e)", note)
            })

            providers = loadedProviders.providers
            providerRegion = loadedProviders.region
            ratings = loadedRatings

            // Preferred pane BEFORE first reveal — never Info→Episodes after paint.
            applyPreferredPaneIfNeeded(animated: false)
            paneRevealToken += 1

            var transaction = Transaction()
            transaction.disablesAnimations = reduceMotion
            withTransaction(transaction) {
                providersReady = true
                ratingsReady = true
            }
            withAnimation(reduceMotion ? nil : MarqueeMotion.standard) {
                diaryReady = true
            }

            if let next = tracking?.nextSeason,
               loaded.seasons?.contains(where: { $0.season_number == next }) == true,
               selectedSeason != next {
                selectedSeason = next
                await loadSeason()
            } else {
                _ = await seasonLoad
            }
        } catch {
            if generation == loadGeneration {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func applyPreferredPaneIfNeeded(animated: Bool) {
        guard !didApplyPreferredPane else { return }
        didApplyPreferredPane = true
        let preferred = TVDetailPane.preferred(for: tracking)
        guard pane != preferred else { return }
        if animated, !reduceMotion {
            withAnimation(MarqueeMotion.micro) { pane = preferred }
        } else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) { pane = preferred }
        }
    }

    func loadSeason() async {
        seasonLoadGeneration += 1
        let generation = seasonLoadGeneration
        let seasonNumber = selectedSeason
        seasonLoading = true
        defer {
            if generation == seasonLoadGeneration {
                seasonLoading = false
            }
        }
        if let season = try? await TMDBService.season(tvId: tvId, season: seasonNumber) {
            guard generation == seasonLoadGeneration else { return }
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
            if isRewatching {
                let res = try await DiaryService.markRewatchEpisode(body)
                applyRewatchMutation(res)
            } else {
                // The mark creates tracking if needed and returns it: no follow-up requests.
                if let updated = try await DiaryService.markEpisode(body) { tracking = updated }
                (episodePlayCounts, episodePlayDates) = EpisodePlays.afterFirstWatch(
                    counts: episodePlayCounts, dates: episodePlayDates, key: key, at: .now
                )
            }
        } catch {
            watchedKeys.remove(key)
        }
    }

    private func performUnmark(_ ep: TVEpisode) async {
        let season = ep.season_number ?? selectedSeason
        let key = "\(season)-\(ep.episode_number)"
        let playsBefore = episodePlayCounts[key] ?? (watchedKeys.contains(key) ? 1 : 0)
        episodePendingUnmark = nil
        Haptics.light()
        let body = markBody(for: ep, afterMark: false)
        do {
            if isRewatching {
                let res = try await DiaryService.unmarkRewatchEpisode(body)
                applyRewatchMutation(res)
                watchedKeys.remove(key)
            } else {
                let res = try await DiaryService.undoEpisodePlay(body)
                applyRewatchMutation(res)
                let playsAfter = res.playCounts?[key] ?? max(0, playsBefore - 1)
                episodePlayCounts[key] = playsAfter > 0 ? playsAfter : nil
                if playsAfter <= 0 {
                    watchedKeys.remove(key)
                    episodeNotes[key] = nil
                    episodeWatchedAt[key] = nil
                }
                if let track = res.tracking {
                    tracking = track
                } else {
                    tracking = try? await DiaryService.tracking(for: idString)
                }
            }
        } catch {
            if playsBefore > 0 { watchedKeys.insert(key) }
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

    private func applyRewatchMutation(_ res: RewatchMutationResponse) {
        if let track = res.tracking { tracking = track }
        if res.session != nil { rewatchSession = res.session }
        if let counts = res.playCounts {
            episodePlayCounts = counts
        }
        if let dates = res.playDates {
            episodePlayDates = dates
        }
        if let total = res.rewatchPlayTotal {
            rewatchPlayTotal = total
        }
        // Structured rewatch: session episodes are the checkmarks.
        // Casual log/undo: keep canonical watchedKeys unless server returned session eps while rewatching.
        if isRewatching, let docs = res.episodes ?? res.session?.episodes {
            watchedKeys = Set(docs.compactMap { doc in
                guard let s = doc.seasonNumber, let e = doc.episodeNumber else { return nil }
                return "\(s)-\(e)"
            })
        }
        if res.completed == true {
            Haptics.success()
        }
    }

    func performLogRewatch(_ ep: TVEpisode) async {
        episodePendingUnmark = nil
        let body = markBody(for: ep, afterMark: true)
        do {
            let res = try await DiaryService.logRewatchEpisode(body)
            applyRewatchMutation(res)
            // Refresh play counts if response omitted map
            if res.playCounts == nil, let state = try? await DiaryService.rewatchState(tvId: idString) {
                episodePlayCounts = state.playCounts ?? episodePlayCounts
                episodePlayDates = state.playDates ?? episodePlayDates
                rewatchPlayTotal = state.rewatchPlayTotal ?? rewatchPlayTotal
                if let track = state.tracking { tracking = track }
            }
            Haptics.success()
        } catch {
            Feedback.failed("Couldn't log that rewatch. Try again.")
        }
    }

    func performSeasonRewatch() async {
        guard let detail, !batching else { return }
        let targets = watchedInSeason.filter(\.hasAired)
        guard !targets.isEmpty else { return }
        batching = true
        defer { batching = false }
        do {
            let body = batchBody(targets, keys: watchedKeys, catalog: targets, detail: detail)
            let res = try await DiaryService.logRewatchBatch(body)
            applyRewatchMutation(res)
            if res.playCounts == nil, let state = try? await DiaryService.rewatchState(tvId: idString) {
                episodePlayCounts = state.playCounts ?? episodePlayCounts
                episodePlayDates = state.playDates ?? episodePlayDates
                rewatchPlayTotal = state.rewatchPlayTotal ?? rewatchPlayTotal
                if let track = state.tracking { tracking = track }
            }
            Haptics.success()
        } catch {
            Feedback.failed("Couldn't log those rewatches. Try again.")
        }
    }

    private func performStartRewatch() async {
        guard let detail, !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let res = try await DiaryService.startRewatch(
                TrackingStartBody(tvId: idString, tvTitle: detail.name, tvPosterImage: detail.poster_path),
                totalEpisodes: detail.number_of_episodes,
                airedEpisodeCount: detail.number_of_episodes
            )
            applyRewatchMutation(res)
            watchedKeys = []
            Haptics.success()
            withAnimation(reduceMotion ? nil : MarqueeMotion.micro) {
                pane = .episodes
            }
        } catch {
            Feedback.failed("Couldn't update the rewatch. Try again.")
        }
    }

    private func performCancelRewatch() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            let res = try await DiaryService.cancelRewatch(tvId: idString)
            applyRewatchMutation(res)
            // Restore canonical checkmarks after cancel.
            if let docs = try? await DiaryService.watchedEpisodes(tvId: idString) {
                watchedKeys = Set(docs.compactMap { doc in
                    guard let s = doc.seasonNumber, let e = doc.episodeNumber else { return nil }
                    return "\(s)-\(e)"
                })
            }
            Haptics.light()
        } catch {
            Feedback.failed("Couldn't update the rewatch. Try again.")
        }
    }

    /// "Mark watched up to here": everything aired before this episode, plus it, that isn't watched.
    func requestMarkUpTo(_ ep: TVEpisode) async {
        guard !batching, let detail else { return }
        if episodeIndex.isEmpty {
            batching = true
            episodeIndex = await fetchEpisodeIndex(from: detail)
            batching = false
        }
        let season = ep.season_number ?? selectedSeason
        let catalog = episodeIndex.isEmpty ? episodes : episodeIndex
        let count = EpisodeOrder.upTo(season: season, episode: ep.episode_number, catalog: catalog, watched: watchedKeys).count
        guard count > 0 else { return }
        if count == 1 {
            await performMark(ep)
            return
        }
        pendingBatch = .markUpTo(season: season, episode: ep.episode_number, count: count)
        showBatchConfirm = true
    }

    // MARK: Log details

    @ViewBuilder
    func episodeLogSheet(_ target: EpisodeLogTarget) -> some View {
        let ep = target.episode
        let season = ep.season_number ?? selectedSeason
        let subject = LogDetailsSubject(
            title: detail?.displayTitle ?? "Episode",
            subtitle: "S\(season) · E\(ep.episode_number)  \(ep.name ?? "")",
            posterPath: detail?.poster_path
        )
        switch target {
        case .new:
            LogDetailsSheet(subject: subject, mode: .new, ratesFilm: false) { draft in
                try await logEpisodeWithDetails(ep, draft: draft)
            }
        case .edit:
            let firstDate = episodeWatchedAt[ep.diaryKey]
            LogDetailsSheet(
                subject: subject,
                mode: .edit,
                initial: LogDetailsDraft(
                    day: firstDate.map { WatchDay.from($0) } ?? .today,
                    note: episodeNotes[ep.diaryKey] ?? ""
                ),
                ratesFilm: false
            ) { draft in
                try await editEpisodeLog(ep, draft: draft)
            }
        }
    }

    private func logEpisodeWithDetails(_ ep: TVEpisode, draft: LogDetailsDraft) async throws {
        let key = ep.diaryKey
        let date = draft.day.date()
        var body = markBody(for: ep, afterMark: true)
        body.watchedAt = ISODate.string(date)
        body.note = draft.note.isEmpty ? nil : draft.note
        watchedKeys.insert(key)
        do {
            if let updated = try await DiaryService.markEpisode(body) { tracking = updated }
        } catch {
            watchedKeys.remove(key)
            throw error
        }
        (episodePlayCounts, episodePlayDates) = EpisodePlays.afterFirstWatch(
            counts: episodePlayCounts, dates: episodePlayDates, key: key, at: date
        )
        episodeWatchedAt[key] = date
        if draft.note.isEmpty { episodeNotes[key] = nil } else { episodeNotes[key] = draft.note }
    }

    private func editEpisodeLog(_ ep: TVEpisode, draft: LogDetailsDraft) async throws {
        let key = ep.diaryKey
        let original = episodeWatchedAt[key]
        // Only a changed day is sent, keeping the log's own time of day.
        let initialDay = original.map { WatchDay.from($0) } ?? .today
        let newDate = draft.day == initialDay ? nil : draft.day.date(timeOf: original)
        _ = try await DiaryService.updateEpisodeLog(
            tvId: idString,
            season: ep.season_number ?? selectedSeason,
            episode: ep.episode_number,
            watchedAt: newDate,
            note: draft.note
        )
        if let newDate { episodeWatchedAt[key] = newDate }
        if draft.note.isEmpty { episodeNotes[key] = nil } else { episodeNotes[key] = draft.note }
        // Dates for this episode (first watch and any rewatches) come back in date order.
        if let state = try? await DiaryService.rewatchState(tvId: idString) {
            episodePlayDates = state.playDates ?? episodePlayDates
        }
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
        case .markUpTo(let season, let episode, _):
            targets = EpisodeOrder.upTo(season: season, episode: episode, catalog: catalog, watched: watchedKeys)
            marking = true
        }
        guard !targets.isEmpty else { return }

        var keys = watchedKeys
        for ep in targets {
            if marking { keys.insert(ep.diaryKey) } else { keys.remove(ep.diaryKey) }
        }
        if marking { watchedKeys = keys }
        if marking { Haptics.medium() } else { Haptics.light() }

        do {
            let body = batchBody(targets, keys: keys, catalog: catalog, detail: detail)
            if isRewatching {
                let response = marking
                    ? try await DiaryService.markRewatchBatch(body)
                    : try await DiaryService.unmarkRewatchBatch(body)
                applyRewatchMutation(response)
            } else if marking {
                let response = try await DiaryService.markBatch(body)
                applyBatch(response)
                if let state = try? await DiaryService.rewatchState(tvId: idString) {
                    episodePlayCounts = state.playCounts ?? episodePlayCounts
                    episodePlayDates = state.playDates ?? episodePlayDates
                    rewatchPlayTotal = state.rewatchPlayTotal ?? rewatchPlayTotal
                }
                if tracking?.status == "completed" {
                    Haptics.success()
                }
            } else {
                // Play-aware season unmark: latest rewatch first, then canonical.
                _ = try await DiaryService.undoEpisodePlayBatch(body)
                if let state = try? await DiaryService.rewatchState(tvId: idString) {
                    episodePlayCounts = state.playCounts ?? [:]
                    episodePlayDates = state.playDates ?? [:]
                    rewatchPlayTotal = state.rewatchPlayTotal ?? 0
                    if let track = state.tracking { tracking = track }
                }
                if let docs = try? await DiaryService.watchedEpisodes(tvId: idString) {
                    watchedKeys = Set(docs.compactMap { doc in
                        guard let s = doc.seasonNumber, let e = doc.episodeNumber else { return nil }
                        return "\(s)-\(e)"
                    })
                }
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
        } catch {
            Feedback.failed("Couldn't update favorites. Try again.")
        }
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
        } catch {
            Feedback.failed("Couldn't update your watchlist. Try again.")
        }
    }

    private func pause() async {
        if let updated = try? await DiaryService.stopTracking(tvId: idString, status: "paused") { tracking = updated }
    }

    private func resume() async {
        if let updated = try? await DiaryService.resumeTracking(tvId: idString) { tracking = updated }
    }
}
