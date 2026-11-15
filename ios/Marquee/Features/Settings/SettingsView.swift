import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var message: String?
    @State private var busy = false
    @State private var importStatus: ImportJob?
    @State private var showImporter = false

    var body: some View {
        Form {
            Section("Profile") {
                TextField("First name", text: $firstName)
                TextField("Last name", text: $lastName)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                TextField("Phone", text: $phone)
                    .keyboardType(.numberPad)
                Button("Save profile") {
                    Task { await saveProfile() }
                }
                .disabled(busy)
            }

            Section("Password") {
                SecureField("Current password", text: $currentPassword)
                SecureField("New password", text: $newPassword)
                Button("Change password") {
                    Task { await changePassword() }
                }
                .disabled(busy || newPassword.count < 6)
            }

            Section("TV Time import") {
                if let importStatus {
                    Text("Status: \(importStatus.status ?? "unknown")")
                        .foregroundStyle(theme.inkMuted)
                    if let report = importStatus.report {
                        Text(report).font(.caption).foregroundStyle(theme.inkMuted)
                    }
                }
                Button("Choose GDPR zip") {
                    showImporter = true
                }
                Button("Refresh status") {
                    Task { await refreshImport() }
                }
            }

            Section("API") {
                Text(AppConfig.apiBaseURL.absoluteString)
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            }

            if let message {
                Section {
                    Text(message).foregroundStyle(theme.accent)
                }
            }

            Section {
                Button("Sign out", role: .destructive) {
                    auth.signOut()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.surface.ignoresSafeArea())
        .navigationTitle("Settings")
        .onAppear {
            firstName = auth.profile?.firstName ?? auth.session?.firstName ?? ""
            lastName = auth.profile?.lastName ?? ""
            email = auth.profile?.email ?? auth.session?.email ?? ""
            phone = auth.profile?.phonenumber ?? ""
        }
        .task { await refreshImport() }
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

    private func saveProfile() async {
        busy = true
        defer { busy = false }
        do {
            try await auth.updateProfile(firstName: firstName, lastName: lastName, email: email, phone: phone)
            message = "Profile saved."
            Haptics.success()
        } catch {
            message = error.localizedDescription
        }
    }

    private func changePassword() async {
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

    private func refreshImport() async {
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
