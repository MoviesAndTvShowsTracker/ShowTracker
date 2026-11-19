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
                                        pendingBatch = .unmarkSeason(
                                            season: selectedSeason,
                                            count: watchedInSeason.count
                                        )
                                        showBatchConfirm = true
                                    } label: {
                                        Label("Unmark season", systemImage: "xmark.circle")
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
                    .symbolEffect(.bounce, value: marked)
                    .scaleEffect(marked ? 1.08 : 1)
                    .animation(MarqueeMotion.standard, value: marked)

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
                    if marked {
                        HStack(spacing: 8) {
                            if let rating = episodeRatings[key], rating > 0 {
                                StarRatingView(rating: .constant(rating / 2), editable: false, size: .caption)
                            }
                            Button("Rate") {
                                episodePendingRate = ep
                                episodeRating = (episodeRatings[key] ?? 0) / 2
                                showEpisodeRatingSheet = true
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.olive)
                        }
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
        .disabled(batching)
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
