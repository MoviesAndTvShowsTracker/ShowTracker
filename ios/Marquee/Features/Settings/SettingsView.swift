import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.marqueeTheme) private var theme
    @State private var confirmSignOut = false
    @State private var confirmDeleteAccount = false
    @State private var deletingAccount = false
    @State private var deleteError: String?

    private var displayName: String {
        let first = auth.profile?.firstName ?? auth.session?.firstName ?? ""
        return first.isEmpty ? "You" : first
    }

    private var episodeAlertsBinding: Binding<Bool> {
        Binding(
            get: { preferences.episodeAlertsEnabled },
            set: { enabled in
                preferences.episodeAlertsEnabled = enabled
                if enabled {
                    PushRegistration.requestAndRegister()
                } else {
                    Task { await EpisodeAlertScheduler.refresh(schedule: [], enabled: false) }
                }
            }
        )
    }

    private var deviceRegionCode: String {
        if let region = Locale.current.region?.identifier, region.count == 2 {
            return region.uppercased()
        }
        return "US"
    }

    private var watchRegionBinding: Binding<String?> {
        Binding(
            get: { preferences.watchRegionCode },
            set: { preferences.watchRegionCode = $0 }
        )
    }

    private static let watchRegionOptions = [
        "US", "CA", "GB", "AU", "IN", "DE", "FR", "BR", "JP", "KR", "MX", "AE"
    ]

    var body: some View {
        List {
            Section {
                accountHeader
            }

            Section {
                AppearancePicker(selection: Bindable(preferences).appearance)
            } header: {
                Text("Look")
            } footer: {
                Text("Night uses a warm lobby grey so posters and captions stay readable.")
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
            } header: {
                Text("Feel")
            } footer: {
                Text("Ambient color slowly drifts olive and pink behind the diary. Turn it off if you want a still canvas.")
            }

            Section {
                Toggle(isOn: episodeAlertsBinding) {
                    SettingsLabel("Episode air alerts", systemImage: "bell.badge")
                }
            } header: {
                Text("Alerts")
            } footer: {
                Text("Marquee reminds you at 9am on days your tracked shows drop a new episode. Add the Up Next widget from your Home Screen for a one-tap jump back in.")
            }

            Section {
                Picker(selection: watchRegionBinding) {
                    Text("Device (\(WatchProviderService.regionDisplayName(deviceRegionCode)))")
                        .tag(String?.none)
                    ForEach(Self.watchRegionOptions, id: \.self) { code in
                        Text("\(WatchProviderService.regionDisplayName(code)) (\(code))")
                            .tag(String?.some(code))
                    }
                } label: {
                    SettingsLabel("Watch region", systemImage: "globe")
                }
            } header: {
                Text("Where to watch")
            } footer: {
                Text("Uses your device region by default — no location permission. Change it here if your streaming catalog is for another country.")
            }

            Section {
                NavigationLink {
                    EditProfileView()
                } label: {
                    SettingsLabel("Profile", systemImage: "person.text.rectangle")
                }
                NavigationLink {
                    ChangePasswordView()
                } label: {
                    SettingsLabel("Password", systemImage: "key")
                }
                NavigationLink {
                    TVTimeImportView()
                } label: {
                    SettingsLabel("TV Time import", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Account")
            }

            Section {
                Button {
                    preferences.clearSearchHistory()
                    Haptics.success()
                } label: {
                    SettingsLabel("Clear search history", systemImage: "clock.arrow.circlepath")
                }
            } header: {
                Text("Diary")
            }

            Section {
                Link(destination: AppConfig.privacyURL) {
                    SettingsLabel("Privacy Policy", systemImage: "hand.raised")
                }
                Link(destination: AppConfig.termsURL) {
                    SettingsLabel("Terms of Service", systemImage: "doc.text")
                }
                Link(destination: AppConfig.tmdbAttributionURL) {
                    SettingsLabel("This product uses the TMDB API", systemImage: "film.stack")
                }
                Link(destination: AppConfig.feedbackEmail) {
                    SettingsLabel("Send feedback", systemImage: "envelope")
                }
                Link(destination: AppConfig.appStoreURL) {
                    SettingsLabel("Rate on the App Store", systemImage: "star")
                }
                Button {
                    Task { await ImageCache.shared.clear() }
                    Haptics.success()
                } label: {
                    SettingsLabel("Clear image cache", systemImage: "photo.on.rectangle.angled")
                }
                LabeledContent("Signed in as") {
                    Text(auth.session?.email ?? "—")
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(1)
                }
                LabeledContent("Version") {
                    Text(appVersion)
                        .foregroundStyle(theme.inkMuted)
                }
            } header: {
                Text("About")
            } footer: {
                Text("Marquee is not endorsed or certified by TMDB. Artwork and titles come from The Movie Database.")
            }

            Section {
                Button("Sign out", role: .destructive) {
                    confirmSignOut = true
                }
                Button(role: .destructive) {
                    confirmDeleteAccount = true
                } label: {
                    if deletingAccount {
                        ProgressView()
                    } else {
                        Text("Delete account")
                    }
                }
                .disabled(deletingAccount)
                if let deleteError {
                    Text(deleteError)
                        .font(.footnote)
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .alert("Sign out of Marquee?", isPresented: $confirmSignOut) {
            Button("Sign out", role: .destructive) {
                auth.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You’ll stay signed out on this iPhone until you sign in again.")
        }
        .alert("Delete your account?", isPresented: $confirmDeleteAccount) {
            Button("Delete account", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes your diary, lists, and sign-in. It can’t be undone.")
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .marqueeCanvas()
        .tint(theme.olive)
        .navigationTitle("Settings")
    }

    private var accountHeader: some View {
        HStack(spacing: 14) {
            Text(String(displayName.prefix(1)).uppercased())
                .font(.title2.weight(.bold))
                .foregroundStyle(MarqueeColor.saltGrey)
                .frame(width: 52, height: 52)
                .background(theme.olive)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text(auth.session?.email ?? "")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func deleteAccount() async {
        deletingAccount = true
        deleteError = nil
        defer { deletingAccount = false }
        do {
            try await auth.deleteAccount()
        } catch {
            deleteError = error.localizedDescription
        }
    }
}

private struct SettingsLabel: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            Text(title)
                .foregroundStyle(theme.ink)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(theme.olive)
        }
    }
}

private struct AppearancePicker: View {
    @Environment(\.marqueeTheme) private var theme
    @Binding var selection: AppPreferences.Appearance

    var body: some View {
        HStack(spacing: 10) {
            ForEach(AppPreferences.Appearance.allCases) { option in
                Button {
                    selection = option
                    Haptics.light()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: option.symbol)
                            .font(.title3)
                        Text(option.title)
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(selection == option ? theme.olive : theme.inkMuted)
                    .background(selection == option ? theme.oliveSoft : theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(selection == option ? theme.olive.opacity(0.35) : theme.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
        .listRowBackground(Color.clear)
    }
}

struct EditProfileView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                TextField("First name", text: $firstName)
                TextField("Last name", text: $lastName)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                TextField("Phone", text: $phone)
                    .keyboardType(.numberPad)
            } footer: {
                Text("This is how you show up in your diary.")
            }

            if let message {
                Section {
                    Text(message).foregroundStyle(theme.olive)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .marqueeCanvas()
        .navigationTitle("Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    Task { await save() }
                }
                .disabled(busy)
            }
        }
        .onAppear {
            firstName = auth.profile?.firstName ?? auth.session?.firstName ?? ""
            lastName = auth.profile?.lastName ?? ""
            email = auth.profile?.email ?? auth.session?.email ?? ""
            phone = auth.profile?.phonenumber ?? ""
        }
    }

    private func save() async {
        busy = true
        defer { busy = false }
        do {
            try await auth.updateProfile(firstName: firstName, lastName: lastName, email: email, phone: phone)
            message = "Saved."
            Haptics.success()
            dismiss()
        } catch {
            message = error.localizedDescription
        }
    }
}

struct ChangePasswordView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                SecureField("Current password", text: $currentPassword)
                SecureField("New password", text: $newPassword)
            } footer: {
                Text("Use at least 6 characters. Skip this if you only sign in with Google.")
            }

            Section {
                Button("Update password") {
                    Task { await change() }
                }
                .disabled(busy || newPassword.count < 6 || currentPassword.isEmpty)
            }

            if let message {
                Section {
                    Text(message).foregroundStyle(theme.olive)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .marqueeCanvas()
        .navigationTitle("Password")
    }

    private func change() async {
        busy = true
        defer { busy = false }
        do {
            try await auth.changePassword(current: currentPassword, newPassword: newPassword)
            currentPassword = ""
            newPassword = ""
            message = "Password updated."
            Haptics.success()
        } catch {
            message = error.localizedDescription
        }
    }
}

struct TVTimeImportView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var importStatus: ImportJob?
    @State private var showImporter = false
    @State private var message: String?
    @State private var busy = false

    var body: some View {
        Form {
            Section {
                Text("Export your data from TV Time (GDPR zip) and Marquee will pull in the shows you’ve logged.")
                    .foregroundStyle(theme.inkMuted)
            }

            Section {
                if let importStatus {
                    LabeledContent("Status") {
                        Text(importStatus.status ?? "unknown")
                            .foregroundStyle(theme.olive)
                    }
                    if let report = importStatus.report ?? importStatus.message {
                        Text(report)
                            .font(.caption)
                            .foregroundStyle(theme.inkMuted)
                    }
                } else {
                    Text("No import running.")
                        .foregroundStyle(theme.inkMuted)
                }
            } header: {
                Text("Last job")
            }

            Section {
                Button {
                    showImporter = true
                } label: {
                    SettingsLabel("Choose GDPR zip", systemImage: "archivebox")
                }
                .disabled(busy)
                Button {
                    Task { await refresh() }
                } label: {
                    SettingsLabel("Refresh status", systemImage: "arrow.clockwise")
                }
            }

            if let message {
                Section {
                    Text(message).foregroundStyle(theme.olive)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .marqueeCanvas()
        .navigationTitle("TV Time")
        .task { await refresh() }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [.zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await upload(url) }
            case .failure(let error):
                message = error.localizedDescription
            }
        }
    }

    private func refresh() async {
        if let res = try? await DiaryService.importStatus() {
            importStatus = res.job
        }
    }

    private func upload(_ url: URL) async {
        busy = true
        defer { busy = false }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let res = try await DiaryService.uploadTVTime(fileURL: url)
            importStatus = res.job
            message = "Import started."
            Haptics.success()
        } catch {
            message = error.localizedDescription
        }
    }
}

extension UTType {
    static var zip: UTType { UTType(filenameExtension: "zip") ?? .archive }
}
