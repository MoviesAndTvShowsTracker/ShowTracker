import SwiftUI

struct DiaryActivityItem: Decodable, Identifiable, Sendable {
    let id: String
    let kind: String
    let mediaId: String?
    let title: String?
    let posterPath: String?
    let subtitle: String?
    let watchedAt: String?
    let rating: Double?
}

private struct DiaryActivityResponse: Decodable, Sendable {
    let success: Bool?
    let items: [DiaryActivityItem]?
}

struct DiaryActivityView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var items: [DiaryActivityItem] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading && items.isEmpty {
                ProgressView().tint(theme.accent).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if items.isEmpty, let error {
                ErrorStateView(message: error) { Task { await load() } }
            } else if items.isEmpty {
                ContentUnavailableView(
                    "No diary yet",
                    systemImage: "book.closed",
                    description: Text("Mark a film or episode and it will show up here.")
                )
            } else {
                List {
                    ForEach(items) { item in
                        row(item)
                            .listRowBackground(theme.surface)
                    }
                    if let error {
                        InlineErrorBanner(message: error) { Task { await load() } }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .marqueeCanvas()
        .navigationTitle("Diary")
        .refreshable { await load() }
        .task { await load() }
    }

    private func row(_ item: DiaryActivityItem) -> some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath, size: "w185"))
                .frame(width: 44, height: 66)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title ?? "Untitled")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.olive)
                }
                Text(formatDate(item.watchedAt))
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer(minLength: 0)
            Text(item.kind == "film" ? "Film" : "TV")
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.olive)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(theme.oliveSoft)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "Watched" }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        guard let date else { return String(raw.prefix(10)) }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func load() async {
        error = nil
        do {
            let res: DiaryActivityResponse = try await APIClient.shared.get("/api/diary/activity")
            items = res.items ?? []
            loading = false
        } catch {
            if items.isEmpty { self.error = error.localizedDescription }
            else { self.error = "Couldn’t refresh diary." }
            loading = false
        }
    }
}
