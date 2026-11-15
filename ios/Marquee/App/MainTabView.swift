import SwiftUI

enum AppTab: Hashable {
    case home, films, tv, search, you
}

struct MainTabView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var tab: AppTab = .home
    @State private var searchFocusToken = 0

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
            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                NavigationStack { SearchView(focusToken: $searchFocusToken) }
            }
            Tab("You", systemImage: "person.fill", value: .you) {
                NavigationStack { ProfileView() }
            }
        }
        .tint(theme.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
        .background(.clear)
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
