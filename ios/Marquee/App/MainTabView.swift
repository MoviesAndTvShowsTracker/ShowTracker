import SwiftUI

enum AppTab: Hashable {
    case home, films, tv, search, you
}

struct MainTabView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var tab: AppTab = .home
    @State private var searchFocusToken = 0
    @State private var showQuickAdd = false
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
            Tab("Search", systemImage: "magnifyingglass", value: .search, role: .search) {
                NavigationStack { SearchView(focusToken: $searchFocusToken) }
            }
            Tab("You", systemImage: "person.fill", value: .you) {
                NavigationStack { ProfileView() }
            }
        }
        .tint(theme.accent)
        .environment(\.marqueePosterNamespace, posterNamespace)
        .overlay(alignment: .bottomTrailing) {
            if tab != .search {
                GlassFAB(systemName: "plus") {
                    Haptics.light()
                    showQuickAdd = true
                }
                .padding(.trailing, 20)
                .padding(.bottom, 88)
                .accessibilityLabel("Quick add")
            }
        }
        .sheet(isPresented: $showQuickAdd) {
            NavigationStack {
                SearchView(focusToken: .constant(1))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showQuickAdd = false }
                        }
                    }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            Haptics.prepare()
            PushRegistration.requestAndRegister()
            PushRegistration.syncIfNeeded()
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
