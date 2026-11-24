import SwiftUI

extension TVDetailView {
    func episodesBlock(_ detail: TVDetail) -> some View {
        let seasons = (detail.seasons ?? []).filter { $0.season_number > 0 }
        let airedSeason = episodes.filter(\.hasAired)
        let watchedAiredSeason = airedSeason.filter { watchedKeys.contains($0.diaryKey) }
        let unwatchedAiredSeason = airedSeason.filter { !watchedKeys.contains($0.diaryKey) }
        let seasonComplete = !airedSeason.isEmpty && unwatchedAiredSeason.isEmpty
        let seasonFraction = airedSeason.isEmpty ? 0 : Double(watchedAiredSeason.count) / Double(airedSeason.count)

        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                SectionKicker(text: "Episodes")
                Text("Mark as you go")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
            }

            if seasons.count > 1 {
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
                            .disabled(batching)
                        }
                    }
                }
            }

            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    if !seasonLoading, !episodes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(selectedSeasonName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.ink)
                                Spacer()
                                Text("\(watchedAiredSeason.count) of \(airedSeason.count) aired")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(theme.inkMuted)
                                    .monospacedDigit()
                            }
                            ProgressTrack(progress: seasonFraction, completed: seasonComplete)

                            HStack(spacing: 8) {
                                if seasonComplete {
                                    Button {
                                        showSeasonActionConfirm = true
                                    } label: {
                                        Label("Season watched", systemImage: "checkmark.circle.fill")
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                    .disabled(batching || watchedInSeason.isEmpty)
                                } else {
                                    Button {
                                        pendingBatch = .markSeason(
                                            season: selectedSeason,
                                            count: unwatchedAiredSeason.count
                                        )
                                        showBatchConfirm = true
                                    } label: {
                                        Label("Mark season", systemImage: "checkmark.circle.fill")
                                    }
                                    .buttonStyle(SecondaryButtonStyle())
                                    .disabled(batching || unwatchedAiredSeason.isEmpty)
                                }

                                if canMarkWholeShow {
                                    Button {
                                        Task { await confirmMarkShow() }
                                    } label: {
                                        if batching {
                                            ProgressView().tint(theme.onAccent)
                                        } else {
                                            Label("Whole show", systemImage: "rectangle.stack.fill.badge.checkmark")
                                        }
                                    }
                                    .buttonStyle(PrimaryButtonStyle())
                                    .disabled(batching)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                        .padding(.bottom, 10)
                    }

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

    var selectedSeasonName: String {
        if let match = detail?.seasons?.first(where: { $0.season_number == selectedSeason }) {
            return match.name ?? "Season \(selectedSeason)"
        }
        return "Season \(selectedSeason)"
    }

    func episodeRow(_ ep: TVEpisode) -> some View {
        let season = ep.season_number ?? selectedSeason
        let key = ep.diaryKey
        let marked = watchedKeys.contains(key)
        let isNext = showProgress(detail: detail, tracking: tracking).next.map {
            $0.season == season && $0.episode == ep.episode_number
        } ?? false

        let plays = episodePlayCounts[key] ?? (marked ? 1 : 0)

        // Not a single outer Button — nesting Rate inside Button labels crashes
        // SwiftUI (EXC_BAD_ACCESS) when playCounts refresh the LazyVStack.
        return HStack(alignment: .top, spacing: 12) {
            Button {
                if marked || plays > 0 {
                    episodePendingUnmark = ep
                    showUnmarkConfirm = true
                } else {
                    Task { await performMark(ep) }
                }
            } label: {
                EpisodePlayMark(plays: marked || plays > 0 ? max(plays, 1) : 0)
            }
            .buttonStyle(.plain)
            .disabled(batching)

            Button {
                if marked || plays > 0 {
                    episodePendingUnmark = ep
                    showUnmarkConfirm = true
                } else {
                    Task { await performMark(ep) }
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    CachedAsyncImage(url: AppConfig.posterURL(path: ep.still_path, size: "w185"))
                        .frame(width: 96, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        )
                        .background(theme.oliveSoft)

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
                                    .foregroundStyle(theme.olive)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(theme.oliveSoft)
                                    .clipShape(Capsule())
                            }
                        }

                        // Catalog facts only — personal watch dates sit on their own line
                        // (TV Time / Trakt keep diary dates out of this chip row).
                        HStack(spacing: 8) {
                            if let air = formatDate(ep.air_date) {
                                Text(air)
                                    .font(.caption)
                                    .foregroundStyle(theme.inkMuted)
                            }
                            if let runtime = ep.runtime, runtime > 0 {
                                Text(MediaMetaLine.formatRuntime(runtime))
                                    .font(.caption)
                                    .foregroundStyle(theme.inkMuted)
                            }
                        }

                        if let first = episodePlayDates[key]?.first.flatMap(shortWatchDate) {
                            Text("Watched \(first)")
                                .font(.caption)
                                .foregroundStyle(theme.inkMuted)
                                .lineLimit(1)
                        }

                        if let overview = ep.overview, !overview.isEmpty {
                            Text(overview)
                                .font(.caption)
                                .foregroundStyle(theme.inkMuted)
                                .lineLimit(2)
                        }
                        if marked, let rating = episodeRatings[key], rating > 0 {
                            StarRatingView(rating: .constant(rating / 2), editable: false, size: .caption)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(batching)

            if marked {
                Button("Rate") {
                    episodePendingRate = ep
                    episodeRating = (episodeRatings[key] ?? 0) / 2
                    showEpisodeRatingSheet = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.olive)
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(minHeight: 72, alignment: .top)
        .background(isNext ? theme.oliveSoft.opacity(0.6) : Color.clear)
        .sensoryFeedback(.success, trigger: marked)
    }

    var episodeRatingSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(episodePendingRate.map { "E\($0.episode_number) · \($0.name ?? "Episode")" } ?? "Episode")
                    .font(.title3.weight(.bold))
                Text("How was it?")
                    .foregroundStyle(theme.inkMuted)
                StarRatingView(rating: $episodeRating, size: .largeTitle)
                    .frame(maxWidth: .infinity)
                Spacer()
                Button("Save rating") {
                    Task { await saveEpisodeRating() }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(episodeRating <= 0)
            }
            .padding(24)
            .marqueeCanvas()
            .navigationTitle("Rate episode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { showEpisodeRatingSheet = false }
                }
            }
        }
    }

    func saveEpisodeRating() async {
        guard let ep = episodePendingRate else { return }
        let season = ep.season_number ?? selectedSeason
        let apiRating = max(1, episodeRating * 2)
        do {
            try await DiaryService.rateEpisode(
                RateEpisodeBody(
                    tvId: idString,
                    seasonNumber: season,
                    episodeNumber: ep.episode_number,
                    rating: apiRating
                )
            )
            episodeRatings[ep.diaryKey] = apiRating
            showEpisodeRatingSheet = false
            Haptics.success()
        } catch {
            // Keep sheet open; banner surfaces elsewhere on next load.
        }
    }

}

/// Empty → check (1st watch) → count in the mark (2×, 3×…) so rewatches aren't a
/// buried caption in the meta row.
struct EpisodePlayMark: View {
    @Environment(\.marqueeTheme) private var theme
    let plays: Int

    var body: some View {
        ZStack {
            if plays <= 0 {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(theme.olive.opacity(0.45))
            } else if plays == 1 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(theme.accentInk)
            } else {
                Circle()
                    .fill(theme.accent)
                    .frame(width: 28, height: 28)
                Text("\(plays)×")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(theme.onAccent)
            }
        }
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .accessibilityLabel(
            plays <= 0
                ? "Not watched"
                : (plays == 1 ? "Watched once" : "Watched \(plays) times")
        )
    }
}
