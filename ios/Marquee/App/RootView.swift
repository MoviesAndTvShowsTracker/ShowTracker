import SwiftUI

struct RootView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme
    @State private var showWelcome = false

    var body: some View {
        Group {
            if auth.isRestoring {
                launchSplash
            } else if auth.isAuthenticated {
                if showWelcome || !OnboardingStore.hasSeenWelcome {
                    WelcomeSplashView {
                        OnboardingStore.hasSeenWelcome = true
                        withAnimation(MarqueeMotion.standard) {
                            showWelcome = false
                        }
                    }
                    .onAppear { showWelcome = !OnboardingStore.hasSeenWelcome }
                } else {
                    MainTabView()
                }
            } else {
                AuthFlowView()
            }
        }
        .animation(MarqueeMotion.standard, value: auth.isAuthenticated)
        .animation(MarqueeMotion.standard, value: showWelcome)
        .respectReducedMotion()
        .onChange(of: auth.isAuthenticated) { _, isAuth in
            if isAuth && !OnboardingStore.hasSeenWelcome {
                showWelcome = true
            }
        }
    }

    private var launchSplash: some View {
        ZStack {
            theme.surface.ignoresSafeArea()
            VStack(spacing: 14) {
                BrandMark(size: 88)
                Text("Marquee")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(theme.olive)
                Text("your watch diary")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                ProgressView()
                    .tint(theme.accent)
                    .padding(.top, 8)
            }
        }
    }
}
