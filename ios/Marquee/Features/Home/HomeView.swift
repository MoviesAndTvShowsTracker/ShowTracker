import SwiftUI

struct HomeView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var feed = HomeFeed.empty
    @State private var loading = true
    @State private var error: String?
    @State private var upNext = UpNextModel(
        mark: { try await EpisodeMarker.markNext(track: $0, catalogTotal: nil, runtime: nil, episodeName: nil) },
        undo: { try await EpisodeMarker.undo($0) },
        preview: { await EpisodeMarker.preview(track: $0) }
    )

    private var greetingName: String {
        let first = auth.profile?.firstName ?? auth.session?.firstName ?? ""
        return first.isEmpty ? "there" : first
    }

    var body: some View {
        let today = Date()
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header(today)

                if !loading && HomeFeedLogic.isStarter(feed) {
                    StarterSection { Task { HomeService.clearCache(); await load() } }
                } else {
                    UpNextSection(model: upNext, pausedCount: feed.pausedCount, loading: loading, today: today)
                    AgendaSection(rows: HomeFeedLogic.agendaRows(feed.thisWeek, today: today))
                    RecentlyLoggedSection(items: feed.recent, today: today)
                    if let recap = feed.recap { WeekPulseRow(recap: recap) }
                    QueueSection(films: feed.films, tv: feed.tv)
                }

                if let message = upNext.errorMessage {
                    InlineErrorBanner(message: message) { upNext.errorMessage = nil }
                        .padding(.horizontal, 20)
                }
                if let error {
                    if HomeFeedLogic.isStarter(feed) {
                        ErrorStateView(message: error) { Task { await load() } }
                    } else {
                        InlineErrorBanner(message: error) { Task { await load() } }
                            .padding(.horizontal, 20)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 28)
        }
        .marqueeCanvas()
        .marqueeLandingChrome()
        .overlay(alignment: .bottom) {
            if let toast = upNext.toast {
                UndoToast(toast: toast) { Task { await upNext.undoLast() } }
                    .padding(.bottom, 12)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast.id) {
                        try? await Task.sleep(for: .seconds(5))
                        if upNext.toast?.id == toast.id { upNext.toast = nil }
                    }
            }
        }
        .animation(reduceMotion ? nil : MarqueeMotion.standard, value: upNext.toast)
        .refreshable { await load() }
        .task {
            upNext.onChange = { Task { await reloadAfterMark() } }
            if UITestingFixtures.emptyDiary { loading = false; return }
            if UITestingFixtures.isEnabled {
                feed.upNext = UITestingFixtures.continueItems.map { UpNextItem(track: $0, nextAirDate: nil) }
                feed.recent = UITestingFixtures.diaryItems
                upNext.replace(feed.upNext)
                loading = false
                return
            }
            await load()
        }
    }

    private func header(_ today: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hey, \(greetingName)")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(theme.ink)
            Text(HomeFeedLogic.headerSubtitle(feed, today: today))
                .font(.subheadline)
                .foregroundStyle(theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .accessibilityAddTraits(.isHeader)
    }

    private func apply(_ next: HomeFeed) {
        feed = next
        upNext.replace(next.upNext)
        let tracks = next.upNext.prefix(6).map(\.track)
        Task { await EpisodeMarker.prefetch(Array(tracks)) }
    }

    private func load() async {
        error = nil
        if loading, let cached = HomeService.cached() {
            apply(cached)
            loading = false
        }
        do {
            let fresh = try await HomeService.load()
            apply(fresh)
            HomeService.store(fresh)
            loading = false
            await afterLoad(fresh)
        } catch {
            self.error = HomeFeedLogic.isStarter(feed)
                ? error.localizedDescription
                : "Couldn’t refresh. Showing last saved home."
            loading = false
        }
    }

    /// After a mark or undo: refresh air dates, recap and recent without a skeleton.
    private func reloadAfterMark() async {
        HomeService.clearCache()
        guard let fresh = try? await HomeService.load() else { return }
        apply(fresh)
        HomeService.store(fresh)
        await afterLoad(fresh)
    }

    private func afterLoad(_ feed: HomeFeed) async {
        let next = feed.upNext.first?.track
        let recap = feed.recap
        WidgetSnapshotStore.save(
            continueTitle: next?.tvTitle,
            continueSubtitle: next.map { ShowProgress.from(track: $0).episodeLine },
            continuePoster: next?.posterPath,
            weekFilms: recap?.filmsThisWeek,
            weekEpisodes: recap?.episodesThisWeek,
            weekMins: recap?.totalMinsThisWeek,
            weekStreak: recap?.streak
        )
        let schedule = feed.thisWeek.filter { $0.kind == "airing" }.map {
            ScheduleEpisode(
                tvId: $0.tvId, title: $0.title, posterPath: $0.posterPath,
                season: $0.season, episode: $0.episode, episodeName: $0.episodeName, airDate: $0.airDate
            )
        }
        await EpisodeAlertScheduler.refresh(schedule: schedule, enabled: preferences.episodeAlertsEnabled)
    }
}
