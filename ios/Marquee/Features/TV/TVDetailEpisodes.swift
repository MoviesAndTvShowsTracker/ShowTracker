import SwiftUI

extension TVDetailView {
    func episodesBlock(_ detail: TVDetail) -> some View {
        let seasons = (detail.seasons ?? []).filter { $0.season_number > 0 }
        let airedSeason = episodes.filter(\.hasAired)
        let watchedAiredSeason = airedSeason.filter { watchedKeys.contains($0.diaryKey) }
        let unwatchedAiredSeason = airedSeason.filter { !watchedKeys.contains($0.diaryKey) }
        let seasonComplete = !airedSeason.isEmpty && unwatchedAiredSeason.isEmpty
        let seasonFraction = airedSeason.isEmpty ? 0 : Double(watchedAiredSeason.count) / Double(airedSeason.count)
        let ratingsSummary = EpisodeRatingsSummary(ratings: episodeRatings, names: episodeNames)

        return VStack(alignment: .leading, spacing: 16) {
            GlassCard(padding: 0) {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 10) {
                            seasonTitle(seasons)
                            Spacer(minLength: 8)
                            if !seasonLoading, !episodes.isEmpty {
                                seasonCount(
                                    watched: watchedAiredSeason.count,
                                    aired: airedSeason.count,
                                    average: ratingsSummary.average(season: selectedSeason)
                                )
                            }
                            seasonMenu(
                                seasonCount: seasons.count,
                                complete: seasonComplete,
                                unwatched: unwatchedAiredSeason.count
                            )
                        }
                        if !seasonLoading, !watchedAiredSeason.isEmpty {
                            ProgressTrack(progress: seasonFraction, completed: seasonComplete)
                                .transition(.opacity)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

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
                                Divider().overlay(theme.border).padding(.leading, 56)
                                episodeRow(ep)
                                    .id(Self.episodeRowID(ep.diaryKey))
                            }
                        }
                    }
                }
            }
            .task(id: flashEpisodeKey) {
                guard flashEpisodeKey != nil else { return }
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.6)) { flashEpisodeKey = nil }
            }

            if ratingsSummary.hasBest, !isRewatching {
                BestEpisodesCard(entries: ratingsSummary.best()) { entry in
                    guard entry.season != selectedSeason else { return }
                    selectedSeason = entry.season
                    Task { await loadSeason() }
                }
            }
        }
    }

    @ViewBuilder
    private func seasonTitle(_ seasons: [TVSeason]) -> some View {
        if seasons.count > 1 {
            Menu {
                Picker("Season", selection: Binding(
                    get: { selectedSeason },
                    set: { next in
                        guard next != selectedSeason else { return }
                        selectedSeason = next
                        Task { await loadSeason() }
                    }
                )) {
                    ForEach(seasons) { season in
                        Text(season.name ?? "Season \(season.season_number)").tag(season.season_number)
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    Text(selectedSeasonName)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.olive)
                }
                .font(.headline)
                .foregroundStyle(theme.ink)
                .contentShape(Rectangle())
            }
            .disabled(batching)
            .accessibilityLabel("Season: \(selectedSeasonName)")
            .accessibilityHint("Choose a season")
        } else {
            Text(selectedSeasonName)
                .font(.headline)
                .foregroundStyle(theme.ink)
                .lineLimit(1)
        }
    }

    private func seasonCount(watched: Int, aired: Int, average: Double?) -> some View {
        HStack(spacing: 6) {
            if let average {
                Label(average.formatted(.number.precision(.fractionLength(1))), systemImage: "star.fill")
                    .labelStyle(.titleAndIcon)
                    .accessibilityLabel("Your average \(average.formatted(.number.precision(.fractionLength(1))))")
                Text("·").accessibilityHidden(true)
            }
            Text(TVShowPageLogic.seasonCountLine(watched: watched, aired: aired, total: episodes.count))
                .contentTransition(.numericText(value: Double(watched)))
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(theme.inkMuted)
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.85)
        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: watched)
    }

    private func seasonMenu(seasonCount: Int, complete: Bool, unwatched: Int) -> some View {
        Menu {
            if complete {
                Button("Watch season again", systemImage: "arrow.clockwise") {
                    Task { await performSeasonRewatch() }
                }
                Button("Remove season watches", systemImage: "minus.circle", role: .destructive) {
                    pendingBatch = .unmarkSeason(season: selectedSeason, count: watchedInSeason.count)
                    showBatchConfirm = true
                }
                .disabled(watchedInSeason.isEmpty)
            } else {
                Button("Mark season watched", systemImage: "checkmark.circle") {
                    pendingBatch = .markSeason(season: selectedSeason, count: unwatched)
                    showBatchConfirm = true
                }
                .disabled(unwatched == 0)
            }
            if TVShowPageLogic.offersWholeShow(seasonCount: seasonCount, canMarkWholeShow: canMarkWholeShow) {
                Button("Mark whole show watched", systemImage: "rectangle.stack.badge.checkmark") {
                    Task { await confirmMarkShow() }
                }
            }
        } label: {
            Group {
                if batching {
                    ProgressView()
                } else {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.olive)
                }
            }
            .frame(width: 36, height: 36)
            .background(theme.oliveSoft, in: Circle())
            .contentShape(Circle())
        }
        .disabled(batching || seasonLoading || episodes.isEmpty)
        .accessibilityLabel("Season actions")
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
        let aired = ep.hasAired
        let flashing = flashEpisodeKey == key

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
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .padding(.vertical, -8)
            .disabled(batching || !aired)

            // The circle marks; the row opens date, rating and note, so a stray tap never logs.
            Button {
                guard aired else { return }
                if isRewatching {
                    if marked || plays > 0 {
                        episodePendingUnmark = ep
                        showUnmarkConfirm = true
                    } else {
                        Task { await performMark(ep) }
                    }
                } else {
                    episodeLogTarget = marked ? .edit(ep) : .new(ep)
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
                                Text("Next")
                                    .font(.caption2.weight(.bold))
                                    .tracking(MarqueeType.labelTracking)
                                    .textCase(.uppercase)
                                    .foregroundStyle(theme.olive)
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

                        if marked, let note = episodeNotes[key] {
                            HStack(alignment: .firstTextBaseline, spacing: 5) {
                                Image(systemName: "text.quote")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(theme.olive)
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(theme.ink.opacity(0.8))
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Your note: \(note)")
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
            .disabled(batching || !aired)
            .accessibilityHint(isRewatching ? "" : (marked ? "Edit date, rating and note" : "Log with date, rating and note"))

        }
        .padding(.horizontal, 6)
        .padding(.vertical, 12)
        .frame(minHeight: 72, alignment: .top)
        .opacity(aired ? 1 : 0.55)
        .background(isNext ? theme.oliveSoft.opacity(0.6) : Color.clear)
        .overlay {
            theme.olive
                .opacity(flashing ? 0.16 : 0)
                .allowsHitTesting(false)
        }
        .contentShape(Rectangle())
        // A tap marks today; a long press offers a date, a note, or catching up in one go.
        .contextMenu {
            if !isRewatching {
                if marked || plays > 0 {
                    if marked {
                        Button("Edit date, rating & note…", systemImage: "calendar.badge.clock") {
                            episodeLogTarget = .edit(ep)
                        }
                    }
                } else {
                    Button("Mark watched", systemImage: "checkmark.circle") {
                        Task { await performMark(ep) }
                    }
                    Button("Log with date & note…", systemImage: "calendar.badge.plus") {
                        episodeLogTarget = .new(ep)
                    }
                    Button("Mark watched up to here", systemImage: "checklist") {
                        Task { await requestMarkUpTo(ep) }
                    }
                }
            }
        }
        .sensoryFeedback(.success, trigger: marked)
    }
}

/// Empty → check (1st watch) → count in the mark (2×, 3×…) so rewatches aren't a
/// buried caption in the meta row.
struct EpisodePlayMark: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let plays: Int

    /// Tapped often when catching up on a season: a quick scale-in, no bounce.
    private var swap: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.8).combined(with: .opacity)
    }

    var body: some View {
        ZStack {
            if plays <= 0 {
                Image(systemName: "circle")
                    .font(.title3)
                    .foregroundStyle(theme.olive.opacity(0.45))
                    .transition(swap)
            } else if plays == 1 {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(theme.accentInk)
                    .transition(swap)
            } else {
                ZStack {
                    Circle()
                        .fill(theme.accent)
                        .frame(width: 28, height: 28)
                    Text("\(plays)×")
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(theme.onAccent)
                        .contentTransition(.numericText(value: Double(plays)))
                }
                .transition(swap)
            }
        }
        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: plays)
        .frame(width: 28, height: 28)
        .contentShape(Rectangle())
        .accessibilityLabel(
            plays <= 0
                ? "Not watched"
                : (plays == 1 ? "Watched once" : "Watched \(plays) times")
        )
    }
}
