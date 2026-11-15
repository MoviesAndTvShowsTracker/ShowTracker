import SwiftUI

@main
struct MarqueeApp: App {
    @State private var auth = AuthStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .marqueeTheme()
                .preferredColorScheme(nil)
        }
    }
}
