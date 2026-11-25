import SwiftUI

enum AppTab: Hashable {
    case home, films, tv, search, you
}

struct MainTabView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var tab: AppTab = {
        switch UITestingFixtures.startTab {
        case "films": .films
        case "tv": .tv
        case "search": .search
        case "you", "stats": .you
        default: .home
        }
    }()
    @State private var searchFocusToken = 0
    @Namespace private var posterNamespace

    var body: some View {
        TabView(selection: tabBinding) {
            Tab("Home", systemImage: "house.fill", value: .home) {
                NavigationStack { HomeView() }
            }
            Tab("Films", systemImage: "film.fill", value: .films) {
                NavigationStack { FilmsLandingView() }
            }
            Tab("TV", systemImage: "tv.fill", value: .tv) {
                NavigationStack { TVLandingView() }
            }
            Tab("Search", systemImage: "magnifyingglass", value: .search) {
                NavigationStack { SearchView(focusToken: $searchFocusToken) }
            }
            Tab("You", systemImage: "person.fill", value: .you) {
                NavigationStack { ProfileView() }
            }
        }
        .tint(theme.accent)
        .environment(\.marqueePosterNamespace, posterNamespace)
        .onAppear {
            Haptics.prepare()
            // Don't prompt for push on every lobby open — sync only if already authorized.
            PushRegistration.syncIfAuthorized()
        }
        // Poster badges and long-press menus everywhere read these; keep them current.
        // Cheap when nothing changed (304 / skipped while fresh).
        .task(id: tab) {
            async let films: Void = FilmDiaryIndex.shared.refresh()
            async let shows: Void = TVDiaryIndex.shared.refresh()
            _ = await (films, shows)
        }
    }

    private var tabBinding: Binding<AppTab> {
        Binding(
            get: { tab },
            set: { newValue in
                if newValue == tab, newValue == .search {
                    searchFocusToken += 1
                }
                tab = newValue
            }
        )
    }
}
