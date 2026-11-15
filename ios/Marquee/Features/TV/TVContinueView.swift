import SwiftUI

struct TVContinueView: View {
    @Environment(\.marqueeTheme) private var theme
    let tvId: Int
    var seed: TrackingRecord?
    var catalogTotal: Int? = nil

    @State private var tracking: TrackingRecord?
    @State private var episode: TVEpisode?
    @State private var catalog: Int?
    @State private var marking = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private var idString: String { String(tvId) }
    private var progress: ShowProgress {
        ShowProgress.from(track: tracking ?? seed, catalogTotal: catalog ?? catalogTotal)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hero
                VStack(alignment: .leading, spacing: 18) {
                    header
                    episodeCard
                    actions
                }
                .padding(20)
                .padding(.bottom, 48)
            }
        }
        .background(theme.surface.ignoresSafeArea())
        .navigationTitle("Continue")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var hero: some View {
        ZStack(alignment: .bottom) {
            CachedAsyncImage(
                url: AppConfig.backdropURL(path: episode?.still_path)
                    ?? AppConfig.backdropURL(path: tracking?.posterPath ?? seed?.posterPath),
                contentMode: .fill
            )
            LinearGradient(
                colors: [.clear, theme.surface.opacity(0.55), theme.surface],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(height: 220)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var header: some View {
        HStack(alignment: .bottom, spacing: 14) {
            CachedAsyncImage(url: AppConfig.posterURL(path: tracking?.posterPath ?? seed?.posterPath))
                .frame(width: 92, height: 138)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: theme.olive.opacity(0.25), radius: 10, y: 6)
                .offset(y: -36)
                .padding(.bottom, -36)

            VStack(alignment: .leading, spacing: 6) {
                SectionKicker(text: "Up next", accented: true)
                Text(tracking?.tvTitle ?? seed?.tvTitle ?? "Continue")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    private var episodeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(progress.episodeLine)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.olive)

                Text(episode?.name ?? progress.next?.name ?? "Next episode")
                    .font(.headline)
                    .foregroundStyle(theme.ink)

                HStack(spacing: 10) {
                    if let air = formatDate(episode?.air_date) {
                        Text(air)
                            .font(.caption)
                            .foregroundStyle(theme.inkMuted)
                    }
                    if let runtime = episode?.runtime, runtime > 0 {
                        Text("\(runtime) min")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.olive)
                    }
                }

                if let overview = episode?.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(4)
                }

                HStack(spacing: 8) {
                    ProgressTrack(progress: progress.fraction, completed: progress.isComplete)
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
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let error {
                Text(error).font(.footnote).foregroundStyle(theme.accent)
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

    private func load() async {
        tracking = (try? await DiaryService.tracking(for: idString)) ?? seed
        if catalog == nil, (tracking?.totalEpisodes ?? 0) == 0, (tracking?.airedEpisodeCount ?? 0) == 0 {
            catalog = (try? await TMDBService.tvDetail(id: tvId))?.number_of_episodes ?? catalogTotal
        }
        await resolveEpisode()
    }

    private func resolveEpisode() async {
        let pointer = progress.next
        let startSeason = pointer?.season ?? tracking?.lastSeason ?? seed?.lastSeason ?? 1
        let startEpisode = pointer?.episode ?? 1

        if let season = try? await TMDBService.season(tvId: tvId, season: startSeason) {
            if let match = season.episodes?.first(where: { $0.episode_number == startEpisode }) {
                episode = match
                return
            }
            if let later = season.episodes?.first(where: { $0.episode_number >= startEpisode }) {
                episode = later
                return
            }
        }
        if let nextSeason = try? await TMDBService.season(tvId: tvId, season: startSeason + 1) {
            episode = nextSeason.episodes?.first { $0.episode_number == 1 }
        }
    }

    private func markNext() async {
        guard let next = progress.next else {
            error = "No next episode."
            return
        }
        marking = true
        defer { marking = false }
        let total = catalog ?? catalogTotal ?? tracking?.totalEpisodes ?? tracking?.airedEpisodeCount
        var followingSeason = next.season
        var followingEpisode = next.episode + 1
        var followingName: String?
        if let season = try? await TMDBService.season(tvId: tvId, season: next.season) {
            if let later = season.episodes?.first(where: { $0.episode_number > next.episode }) {
                followingSeason = later.season_number ?? next.season
                followingEpisode = later.episode_number
                followingName = later.name
            } else {
                followingSeason = next.season + 1
                followingEpisode = 1
            }
        }
        do {
            try await DiaryService.markEpisode(
                MarkEpisodeBody(
                    tvId: idString,
                    seasonNumber: next.season,
                    episodeNumber: next.episode,
                    runtimeMinutes: episode?.runtime,
                    episodeName: episode?.name ?? next.name,
                    tvTitle: tracking?.tvTitle ?? seed?.tvTitle,
                    tvPosterImage: tracking?.posterPath ?? seed?.posterPath,
                    totalEpisodes: total,
                    airedEpisodeCount: total,
                    nextSeason: followingSeason,
                    nextEpisode: followingEpisode,
                    nextEpisodeName: followingName
                )
            )
            Haptics.success()
            tracking = try await DiaryService.tracking(for: idString)
            await resolveEpisode()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
