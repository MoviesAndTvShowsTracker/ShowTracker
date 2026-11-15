import SwiftUI

@main
struct MarqueeApp: App {
    @State private var auth = AuthStore()
    @State private var preferences = AppPreferences()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(preferences)
                .marqueeTheme()
                .preferredColorScheme(preferences.appearance.colorScheme)
                .onAppear { GoogleAuth.configure() }
                .onOpenURL { url in
                    _ = GoogleAuth.handle(url)
                }
        }
    }
}
