import SwiftUI
import StoreKit
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.marqueeTheme) private var theme
    @State private var confirmSignOut = false
    @State private var confirmDeleteAccount = false
    @State private var deletingAccount = false
    @State private var deleteError: String?
    @Environment(\.requestReview) private var requestReview

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

    var body: some View {
        List {
            Section {
                NavigationLink {
                    EditProfileView()
                } label: {
                    accountHeader
                }
            }

            Section {
                NavigationLink {
                    AppearanceSettingsView()
                } label: {
                    SettingsLabel("Appearance", systemImage: "paintbrush")
                }
                NavigationLink {
                    StreamingSettingsView()
                } label: {
                    LabeledContent {
                        Text(servicesSummary).foregroundStyle(theme.inkMuted)
                    } label: {
                        SettingsLabel("Streaming", systemImage: "play.tv")
                    }
                }
                Toggle(isOn: episodeAlertsBinding) {
                    SettingsLabel("New episode alerts", systemImage: "bell.badge")
                }
            } header: {
                Text("Preferences")
            } footer: {
                Text("A 9 am reminder on days a show you track has a new episode.")
            }

            Section {
                NavigationLink {
                    TVTimeImportView()
                } label: {
                    SettingsLabel("Import from TV Time", systemImage: "square.and.arrow.down")
                }
                NavigationLink {
                    ExportDiaryView()
                } label: {
                    SettingsLabel("Export your diary", systemImage: "square.and.arrow.up")
                }
                Button {
                    preferences.clearSearchHistory()
                    Haptics.success()
                    Feedback.done("Search history cleared")
                } label: {
                    SettingsLabel("Clear search history", systemImage: "clock.arrow.circlepath")
                }
                Button {
                    Task { await ImageCache.shared.clear() }
                    Haptics.success()
                    Feedback.done("Image cache cleared")
                } label: {
                    SettingsLabel("Clear image cache", systemImage: "photo.on.rectangle.angled")
                }
            } header: {
                Text("Your data")
            }

            Section {
                NavigationLink {
                    ChangePasswordView()
                } label: {
                    SettingsLabel("Password", systemImage: "key")
                }
                Button {
                    confirmSignOut = true
                } label: {
                    SettingsLabel("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                }
            } header: {
                Text("Account")
            }

            Section {
                Link(destination: AppConfig.feedbackEmail) {
                    SettingsLabel("Send feedback", systemImage: "envelope")
                }
                Button {
                    requestReview()
                } label: {
                    SettingsLabel("Rate Marquee", systemImage: "star")
                }
                Link(destination: AppConfig.privacyURL) {
                    SettingsLabel("Privacy Policy", systemImage: "hand.raised")
                }
                Link(destination: AppConfig.termsURL) {
                    SettingsLabel("Terms of Service", systemImage: "doc.text")
                }
                Link(destination: AppConfig.tmdbAttributionURL) {
                    HStack {
                        SettingsLabel("Data from TMDB", systemImage: "film.stack")
                        Spacer(minLength: 12)
                        // TMDB's terms ask apps to credit them with their logo.
                        Image("TMDBLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 11)
                            .accessibilityHidden(true)
                    }
                }
                LabeledContent("Version") {
                    Text(appVersion).foregroundStyle(theme.inkMuted).monospacedDigit()
                }
            } header: {
                Text("About")
            } footer: {
                Text("Marquee uses the TMDB API but is not endorsed or certified by TMDB.")
            }

            Section {
                Button(role: .destructive) {
                    confirmDeleteAccount = true
                } label: {
                    HStack {
                        Spacer()
                        if deletingAccount { ProgressView() } else { Text("Delete account") }
                        Spacer()
                    }
                }
                .disabled(deletingAccount)
            } footer: {
                if let deleteError {
                    Text(deleteError).foregroundStyle(theme.accentInk)
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

    private var servicesSummary: String {
        let count = preferences.preferredProviderIds.count
        return count == 0 ? "None" : "\(count)"
    }

    private var accountHeader: some View {
        HStack(spacing: 14) {
            Group {
                if let avatar = ProfileAvatarStore.load() {
                    Image(uiImage: avatar).resizable().scaledToFill()
                } else {
                    Text(String(displayName.prefix(1)).uppercased())
                        .font(.title2.weight(.bold))
                        .foregroundStyle(MarqueeColor.saltGrey)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(theme.olive)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Text(auth.session?.email ?? "")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Edit your profile")
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

struct SettingsLabel: View {
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

struct AppearancePicker: View {
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
    @State private var originalEmail = ""
    @State private var currentPassword = ""
    @State private var message: String?
    @State private var busy = false

    private var emailChanging: Bool { ProfileEdit.needsPassword(original: originalEmail, edited: email) }

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

            if emailChanging {
                Section {
                    SecureField("Current password", text: $currentPassword)
                        .textContentType(.password)
                } footer: {
                    Text("Changing your email needs your password. Signed in with Google or Apple? Set one with Forgot password first.")
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
            originalEmail = email
            phone = auth.profile?.phonenumber ?? ""
        }
    }

    private func save() async {
        busy = true
        defer { busy = false }
        do {
            try await auth.updateProfile(
                firstName: firstName, lastName: lastName, email: email, phone: phone,
                currentPassword: emailChanging ? currentPassword : nil
            )
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
                Text("Use at least 6 characters. Skip this if you only sign in with Apple or Google — or use Forgot password on the sign-in screen to set one.")
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
