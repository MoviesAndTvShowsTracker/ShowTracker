import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showWelcome = false
    @State private var revealed = false
    @State private var settled = false
    @State private var bootStarted = Date()

    var body: some View {
        ZStack {
            ZStack {
                theme.surface.ignoresSafeArea()
                destination
            }
            .modifier(LaunchRevealMask(revealed: revealed))
            .allowsHitTesting(revealed)

            // Static-frame colour covers everything outside the growing window until settled.
            if !settled {
                LaunchRevealCover(revealed: revealed)
                LaunchSplashView(revealed: revealed)
            }

            FeedbackBanner()
        }
        .animation(reduceMotion ? nil : MarqueeMotion.standard, value: showWelcome)
        .respectReducedMotion()
        .onChange(of: auth.isRestoring) { _, _ in
            Task { await scheduleReveal() }
        }
        .onChange(of: auth.isAuthenticated) { _, isAuth in
            if isAuth && !OnboardingStore.hasSeenWelcome {
                showWelcome = true
            }
        }
        .task { await scheduleReveal() }
    }

    @ViewBuilder
    private var destination: some View {
        if auth.isAuthenticated {
            authenticatedDestination
        } else if UITestingFixtures.isEnabled {
            #if DEBUG
            // Fake session path for offline UI tests only.
            if let kind = UITestingFixtures.previewLogSheet {
                LogSheetPreviewHost(kind: kind)
            } else if let movieId = UITestingFixtures.previewMovieId {
                previewDetailStack { MovieDetailView(movieId: movieId) }
            } else if let tvId = UITestingFixtures.previewTVId {
                previewDetailStack { TVDetailView(tvId: tvId) }
            } else {
                AuthFlowView()
            }
            #else
            AuthFlowView()
            #endif
        } else {
            AuthFlowView()
        }
    }

    @ViewBuilder
    private var authenticatedDestination: some View {
        #if DEBUG
        if let kind = UITestingFixtures.previewLogSheet {
            LogSheetPreviewHost(kind: kind)
        } else if let movieId = UITestingFixtures.previewMovieId {
            previewDetailStack { MovieDetailView(movieId: movieId) }
        } else if let tvId = UITestingFixtures.previewTVId {
            previewDetailStack { TVDetailView(tvId: tvId) }
        } else if showWelcome || !OnboardingStore.hasSeenWelcome {
            welcomeDestination
        } else {
            MainTabView()
        }
        #else
        if showWelcome || !OnboardingStore.hasSeenWelcome {
            welcomeDestination
        } else {
            MainTabView()
        }
        #endif
    }

    #if DEBUG
    /// Mirrors Search → detail: searchable is *active* on the parent, then detail
    /// pushes — same handoff that used to ignore toolbar hide / soft edge.
    private struct PreviewSearchPushStack<Detail: View>: View {
        @ViewBuilder var detail: () -> Detail
        @State private var query = "dune"
        @State private var searching = true
        @State private var showDetail = false

        var body: some View {
            NavigationStack {
                Color.clear
                    .navigationTitle("Search")
                    .navigationBarTitleDisplayMode(.inline)
                    .searchable(
                        text: $query,
                        isPresented: $searching,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Title, show, or franchise"
                    )
                    .searchPresentationToolbarBehavior(.avoidHidingContent)
                    .navigationDestination(isPresented: $showDetail) {
                        detail()
                    }
                    .onAppear {
                        // Push while search is still active — the failure mode.
                        showDetail = true
                    }
            }
        }
    }

    @ViewBuilder
    private func previewDetailStack<Content: View>(@ViewBuilder content: @escaping () -> Content) -> some View {
        if UITestingFixtures.previewViaSearch {
            PreviewSearchPushStack(detail: content)
        } else {
            NavigationStack { content() }
        }
    }
    #endif

    private var welcomeDestination: some View {
        WelcomeSplashView {
            OnboardingStore.hasSeenWelcome = true
            withAnimation(MarqueeMotion.standard) {
                showWelcome = false
            }
        }
        .onAppear { showWelcome = !OnboardingStore.hasSeenWelcome }
    }

    /// Reveal once the session has restored and the minimum has passed, or at the cap.
    @MainActor
    private func scheduleReveal() async {
        guard !revealed else { return }
        let elapsed = Date().timeIntervalSince(bootStarted)
        let wait = LaunchTiming.revealDelay(elapsed: elapsed, restored: !auth.isRestoring)
            ?? (LaunchTiming.maximum - elapsed)
        if wait > 0 {
            try? await Task.sleep(for: .seconds(wait))
        }
        reveal()
    }

    @MainActor
    private func reveal() {
        guard !revealed else { return }
        let curve: Animation = reduceMotion
            ? .easeOut(duration: 0.25)
            : .spring(response: 0.65, dampingFraction: 1)
        withAnimation(curve) { revealed = true }
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            settled = true
        }
    }
}
