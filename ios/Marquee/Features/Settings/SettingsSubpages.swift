import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.marqueeTheme) private var theme

    var body: some View {
        List {
            Section {
                AppearancePicker(selection: Bindable(preferences).appearance)
            } footer: {
                Text("Night uses a warm lobby grey so posters stay readable.")
            }

            Section {
                Toggle(isOn: Bindable(preferences).blobsEnabled) {
                    SettingsLabel("Ambient color", systemImage: "circle.hexagongrid.fill")
                }
                Toggle(isOn: Bindable(preferences).heroAutoplay) {
                    SettingsLabel("Autoplay carousels", systemImage: "play.square.stack")
                }
                Toggle(isOn: Bindable(preferences).hapticsEnabled) {
                    SettingsLabel("Haptics", systemImage: "hand.tap")
                }
                Picker(selection: Bindable(preferences).gridDensity) {
                    Text("Cozy").tag(GridDensity.cozy)
                    Text("Compact").tag(GridDensity.compact)
                } label: {
                    SettingsLabel("Poster size", systemImage: "square.grid.2x2")
                }
            } footer: {
                Text("Ambient color drifts olive and pink behind the diary. Turn it off for a still background.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .marqueeCanvas()
        .tint(theme.olive)
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StreamingSettingsView: View {
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.marqueeTheme) private var theme

    private static let regions = ["US", "CA", "GB", "AU", "IN", "DE", "FR", "BR", "JP", "KR", "MX", "AE"]

    private var deviceRegion: String {
        if let region = Locale.current.region?.identifier, region.count == 2 { return region.uppercased() }
        return "US"
    }

    private var regionBinding: Binding<String?> {
        Binding(get: { preferences.watchRegionCode }, set: { preferences.watchRegionCode = $0 })
    }

    var body: some View {
        List {
            Section {
                StreamingFilterBar(selected: Bindable(preferences).preferredProviderIds, showLabels: true)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                    .listRowBackground(Color.clear)
            } header: {
                Text("Your services")
            } footer: {
                Text("Films and TV use these for “On your services”.")
            }

            Section {
                Picker(selection: regionBinding) {
                    Text("Device (\(WatchProviderService.regionDisplayName(deviceRegion)))").tag(String?.none)
                    ForEach(Self.regions, id: \.self) { code in
                        Text(WatchProviderService.regionDisplayName(code)).tag(String?.some(code))
                    }
                } label: {
                    SettingsLabel("Region", systemImage: "globe")
                }
            } footer: {
                Text("Where-to-watch uses your device region unless you pick another.")
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .marqueeCanvas()
        .tint(theme.olive)
        .navigationTitle("Streaming")
        .navigationBarTitleDisplayMode(.inline)
    }
}
