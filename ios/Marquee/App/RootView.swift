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
            theme.surface.ignoresSafeArea()

            destination
                .modifier(LaunchReveal(revealed: revealed, settled: settled))
                .allowsHitTesting(revealed)

            AmbientBlobs()
                .opacity(revealed ? 1 : 0)
                .allowsHitTesting(false)

            launchSplash
                .scaleEffect(revealed ? 1.48 : 1)
                .opacity(revealed ? 0 : 1)
                .blur(radius: revealed ? 6 : 0)
                .allowsHitTesting(!revealed)
                .accessibilityHidden(revealed)
        }
        .animation(reduceMotion ? nil : MarqueeMotion.standard, value: showWelcome)
        .respectReducedMotion()
        .onChange(of: auth.isRestoring) { _, restoring in
            if !restoring { Task { await playHandoff() } }
        }
        .onChange(of: auth.isAuthenticated) { _, isAuth in
            if isAuth && !OnboardingStore.hasSeenWelcome {
                showWelcome = true
            }
        }
        .task {
            if !auth.isRestoring {
                await playHandoff()
            }
        }
    }

    @ViewBuilder
    private var destination: some View {
        if auth.isAuthenticated {
            authenticatedDestination
        } else if UITestingFixtures.isEnabled {
            #if DEBUG
            // Fake session path for offline UI tests only.
            if let movieId = UITestingFixtures.previewMovieId {
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
        if let movieId = UITestingFixtures.previewMovieId {
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

    private var launchSplash: some View {
        VStack(spacing: 16) {
            BrandMark(size: 128, lit: true)
            Text("Marquee")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(theme.olive)
            Text("your watch diary")
                .font(.subheadline)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @MainActor
    private func playHandoff() async {
        guard !revealed else { return }
        let remaining = 0.75 - Date().timeIntervalSince(bootStarted)
        if remaining > 0 {
            try? await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.01) : MarqueeMotion.zoom) {
            revealed = true
        }
        try? await Task.sleep(nanoseconds: 900_000_000)
        settled = true
    }
}

/// Applied only during launch. Dropped after settle so NavigationStack
/// zoom/pop is not fighting a parent scaleEffect.
private struct LaunchReveal: ViewModifier {
    var revealed: Bool
    var settled: Bool

    func body(content: Content) -> some View {
        if settled {
            content
        } else {
            content
                .scaleEffect(revealed ? 1 : 1.08)
                .opacity(revealed ? 1 : 0)
                .blur(radius: revealed ? 0 : 12)
        }
    }
}
