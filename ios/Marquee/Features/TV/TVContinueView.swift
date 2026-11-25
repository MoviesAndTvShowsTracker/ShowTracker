import SwiftUI

struct TVContinueView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tvId: Int
    var seed: TrackingRecord?
    var catalogTotal: Int? = nil

    @State private var tracking: TrackingRecord?
    @State private var episode: TVEpisode?
    @State private var catalog: Int?
    @State private var marking = false
    @State private var error: String?

    private var idString: String { String(tvId) }
    private var progress: ShowProgress {
        ShowProgress.from(track: tracking ?? seed, catalogTotal: catalog ?? catalogTotal)
    }

    private var posterURL: URL? {
        AppConfig.posterURL(path: seed?.posterPath ?? tracking?.posterPath)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                poster
                header
                episodeCard
                    .frame(minHeight: 168, alignment: .top)
                actions
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 48)
        }
        .marqueeCanvas()
        .navigationTitle("Continue")
        .navigationBarTitleDisplayMode(.inline)
        .task { await hydrate() }
    }

    private var poster: some View {
        CachedAsyncImage(url: posterURL)
            .frame(width: 168, height: 252)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: theme.olive.opacity(0.22), radius: 16, y: 8)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    private var header: some View {
        VStack(spacing: 8) {
            SectionKicker(text: "Up next", accented: true)
            Text(seed?.tvTitle ?? tracking?.tvTitle ?? "Continue")
                .font(.title.weight(.bold))
                .foregroundStyle(theme.ink)
                .multilineTextAlignment(.center)
            Text(progress.episodeLine)
                .font(.headline)
                .foregroundStyle(theme.olive)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .animation(reduceMotion ? nil : MarqueeMotion.standard, value: progress.episodeLine)
    }

    private var episodeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(episodeName)
                    .contentTransition(.opacity)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .frame(minHeight: 28, alignment: .top)
                    .opacity(episodeName == " " ? 0 : 1)

                Text(metaLine.isEmpty ? " " : metaLine)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.olive)
                    .opacity(metaLine.isEmpty ? 0 : 1)

                Text(overviewText)
                    .contentTransition(.opacity)
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(4)
                    .frame(minHeight: 64, alignment: .top)
                    .opacity(overviewText == " " ? 0 : 1)

                HStack(spacing: 8) {
                    ProgressTrack(progress: progress.fraction, completed: progress.isComplete)
                    Text(progress.total > 0 ? "\(progress.percent)%" : "\(progress.watched) ep")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.olive)
                        .monospacedDigit()
                        .contentTransition(.numericText(value: Double(progress.watched)))
                        .frame(minWidth: 36, alignment: .trailing)
                }
                Text(progress.caption)
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
                    .contentTransition(.numericText(value: Double(progress.watched)))
            }
            .animation(reduceMotion ? nil : MarqueeMotion.standard, value: progress.watched)
            .animation(reduceMotion ? nil : MarqueeMotion.standard, value: episode?.id)
        }
    }

    private var overviewText: String {
        if let overview = episode?.overview, !overview.isEmpty { return overview }
        return " "
    }

    private var episodeName: String {
        if let name = episode?.name, !name.isEmpty { return name }
        if let name = progress.next?.name, !name.isEmpty { return name }
        return " "
    }

    private var metaLine: String {
        var parts: [String] = []
        if let air = formatDate(episode?.air_date) { parts.append(air) }
        if let runtime = episode?.runtime, runtime > 0 { parts.append(MediaMetaLine.formatRuntime(runtime)) }
        return parts.joined(separator: " · ")
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let error {
                InlineErrorBanner(message: error) {
                    Task { await markNext() }
                }
            }

            Button {
                Task { await markNext() }
            } label: {
                if marking {
                    ProgressView().tint(theme.onAccent)
                } else if let next = progress.next {
                    Text("Mark S\(next.season)E\(next.episode) watched")
                } else {
                    Text("Mark watched")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(marking || progress.next == nil)

            NavigationLink {
                TVDetailView(tvId: tvId)
            } label: {
                Text("Open show")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.olive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(PressablePosterStyle())
        }
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

    private func hydrate() async {
        let track: TrackingRecord?
        if let seed {
            track = seed
        } else {
            track = try? await DiaryService.tracking(for: idString)
        }
        async let catalogValue = fetchCatalog(for: track)
        async let episodeValue = fetchEpisode(for: track)
        let resolvedCatalog = await catalogValue
        let resolvedEpisode = await episodeValue

        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            tracking = track
            if let resolvedCatalog { catalog = resolvedCatalog }
            episode = resolvedEpisode
        }
    }

    private func fetchCatalog(for track: TrackingRecord?) async -> Int? {
        if let existing = catalogTotal, existing > 0 { return existing }
        if let aired = track?.airedEpisodeCount, aired > 0 { return aired }
        if let total = track?.totalEpisodes, total > 0 { return total }
        return (try? await TMDBService.tvDetail(id: tvId))?.number_of_episodes
    }

    private func fetchEpisode(for track: TrackingRecord?) async -> TVEpisode? {
        let pointer = ShowProgress.from(track: track, catalogTotal: catalogTotal).next
        let startSeason = pointer?.season ?? track?.lastSeason ?? 1
        let startEpisode = pointer?.episode ?? 1

        if let season = try? await TMDBService.season(tvId: tvId, season: startSeason) {
            if let match = season.episodes?.first(where: { $0.episode_number == startEpisode }) {
                return match
            }
            if let later = season.episodes?.first(where: { $0.episode_number >= startEpisode }) {
                return later
            }
        }
        if let nextSeason = try? await TMDBService.season(tvId: tvId, season: startSeason + 1) {
            return nextSeason.episodes?.first { $0.episode_number == 1 }
        }
        return nil
    }

    private func markNext() async {
        guard let track = tracking ?? seed, progress.next != nil else {
            error = "No next episode."
            return
        }
        marking = true
        defer { marking = false }
        do {
            let result = try await EpisodeMarker.markNext(
                track: track,
                catalogTotal: catalog ?? catalogTotal,
                runtime: episode?.runtime,
                episodeName: episode?.name
            )
            Haptics.success()
            tracking = result.updated ?? tracking
            episode = await fetchEpisode(for: tracking)
        } catch {
            self.error = error.localizedDescription
        }
    }
}
