import SwiftUI

/// The block under the hero: where you are with the show, and the one thing to do next.
extension TVDetailView {
    static func episodeRowID(_ key: String) -> String { "ep-\(key)" }
    static let paneSwitcherID = "tv-pane-switcher"

    var headerState: TVHeaderState {
        TVShowPageLogic.headerState(
            status: tracking?.status,
            showRating: showRating,
            seasons: (detail?.seasons ?? []).map(\.season_number),
            firstAirDate: detail?.first_air_date,
            showStatus: detail?.status,
            today: Date()
        )
    }

    func header(_ detail: TVDetail) -> some View {
        let state = headerState
        return VStack(alignment: .leading, spacing: 12) {
            if let tracking {
                statusCard(detail, tracking: tracking, state: state)
            }
            HStack(spacing: 10) {
                primaryAction(detail, state: state)
                iconActions(detail, state: state)
            }
            .disabled(busy)
        }
        .animation(reduceMotion ? nil : MarqueeMotion.standard, value: state)
    }

    // MARK: Status

    @ViewBuilder
    private func statusCard(_ detail: TVDetail, tracking: TrackingRecord, state: TVHeaderState) -> some View {
        let progress = showProgress(detail: detail, tracking: tracking)
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(statusLabel(tracking, state: state))
                    .font(.caption.weight(.bold))
                    .tracking(MarqueeType.labelTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(theme.olive)

                if case .finished = state {
                    finishedSummary(progress)
                } else {
                    Text(episodeTitle(progress.next, fallback: progress.episodeLine))
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .lineLimit(2)
                    HStack(spacing: 10) {
                        ProgressTrack(progress: progress.fraction, completed: false)
                        if progress.total > 0 {
                            Text("\(progress.watched) of \(progress.total) · \(progress.percent)%")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.inkMuted)
                                .monospacedDigit()
                                .fixedSize()
                        }
                    }
                    if state == .rewatching {
                        Text("Original history kept.")
                            .font(.caption)
                            .foregroundStyle(theme.inkMuted)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func finishedSummary(_ progress: ShowProgress) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(rewatchPlayTotal > 0
                 ? "\(progress.caption) · \(rewatchPlayTotal) rewatch play\(rewatchPlayTotal == 1 ? "" : "s")"
                 : progress.caption)
                .font(.subheadline)
                .foregroundStyle(theme.inkMuted)
            if showRating > 0 {
                Button { showRatingSheet = true } label: {
                    StarRatingView(rating: $showRating, editable: false, size: .body)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Your rating, \(showRating.formatted()) stars. Edit")
            }
        }
    }

    private func statusLabel(_ tracking: TrackingRecord, state: TVHeaderState) -> String {
        switch state {
        case .rewatching: return "Rewatch #\(rewatchSession?.sessionNumber ?? 1)"
        case .paused: return tracking.status == "dropped" ? "Stopped" : "Paused"
        case .finished:
            let times = tracking.timesCompleted ?? 1
            return times > 1 ? "Finished ×\(times)" : "Finished"
        default: return "Up next"
        }
    }

    private func episodeTitle(_ pointer: EpisodePointer?, fallback: String) -> String {
        guard let pointer else { return fallback }
        let code = "S\(pointer.season) · E\(pointer.episode)"
        if let name = pointer.name, !name.isEmpty { return "\(code)  \(name)" }
        return code
    }

    // MARK: Actions

    @ViewBuilder
    private func primaryAction(_ detail: TVDetail, state: TVHeaderState) -> some View {
        switch state {
        case .notStarted(let season):
            Button {
                Task { await startWatching(season: season) }
            } label: {
                Text("Start with S\(season) · E1")
            }
            .buttonStyle(PrimaryButtonStyle())
        case .premieres(let label):
            Text(label)
                .font(.headline)
                .foregroundStyle(theme.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .watching, .rewatching:
            NavigationLink {
                TVContinueView(tvId: tvId, seed: tracking)
            } label: {
                Text(state == .rewatching ? "Continue rewatch" : "Continue")
            }
            .buttonStyle(PrimaryButtonStyle())
        case .paused:
            Button("Resume") { Task { await resume() } }
                .buttonStyle(PrimaryButtonStyle())
        case .finished(let rated):
            if rated {
                Spacer(minLength: 0)
            } else {
                Button("Rate the show") { showRatingSheet = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    @ViewBuilder
    private func iconActions(_ detail: TVDetail, state: TVHeaderState) -> some View {
        HeaderIconButton(
            systemImage: favorited ? "heart.fill" : "heart",
            label: favorited ? "Favorited" : "Favorite",
            active: favorited
        ) { Task { await toggleFavorite(detail) } }

        switch state {
        case .notStarted, .premieres:
            HeaderIconButton(
                systemImage: watchlisted ? "bookmark.fill" : "bookmark",
                label: watchlisted ? "On watchlist" : "Add to watchlist",
                active: watchlisted
            ) { Task { await toggleWatchlist(detail) } }
        default:
            Menu {
                if state != .finished(rated: false) {
                    Button(showRating > 0 ? "Change rating" : "Rate show", systemImage: "star") {
                        showRatingSheet = true
                    }
                }
                if state == .watching {
                    Button("Pause", systemImage: "pause.circle") { Task { await pause() } }
                }
                if case .finished = state {
                    Button("Start rewatch", systemImage: "arrow.clockwise") { showStartRewatchConfirm = true }
                }
                if state == .rewatching {
                    Button("Cancel rewatch", systemImage: "xmark.circle", role: .destructive) {
                        showCancelRewatchConfirm = true
                    }
                }
            } label: {
                HeaderIconLabel(systemImage: "ellipsis", active: false)
            }
            .accessibilityLabel("More actions")
        }
    }

    /// Opens Episodes on the first episode and points at it; marking stays the user's tap.
    func startWatching(season: Int) async {
        Haptics.light()
        if selectedSeason != season || episodes.isEmpty {
            selectedSeason = season
            await loadSeason()
        }
        withAnimation(reduceMotion ? nil : MarqueeMotion.micro) { pane = .episodes }
        // Let the list exist before asking the scroll view to find the row.
        await Task.yield()
        let key = "\(season)-1"
        flashEpisodeKey = key
        // E1 is the first row: land on the tabs so the season row stays in view above it.
        scrollTarget = Self.paneSwitcherID
    }
}

private struct HeaderIconLabel: View {
    @Environment(\.marqueeTheme) private var theme
    let systemImage: String
    let active: Bool

    var body: some View {
        Image(systemName: systemImage)
            .font(.body.weight(.semibold))
            .foregroundStyle(active ? theme.accentInk : theme.olive)
            .frame(width: 50, height: 50)
            .background(theme.oliveSoft, in: Circle())
            .contentShape(Circle())
    }
}

private struct HeaderIconButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let systemImage: String
    let label: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HeaderIconLabel(systemImage: systemImage, active: active)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(PressablePosterStyle())
        .accessibilityLabel(label)
        .sensoryFeedback(.selection, trigger: active)
    }
}
