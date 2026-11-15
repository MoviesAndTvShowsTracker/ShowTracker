import SwiftUI

struct TVLibraryView: View {
    @Environment(\.marqueeTheme) private var theme
    var initialTab: LibraryTab = .watching
    @State private var tab: LibraryTab

    init(initialTab: LibraryTab = .watching) {
        self.initialTab = initialTab
        _tab = State(initialValue: initialTab)
    }
    @State private var items: [TrackingRecord] = []
    @State private var summary: LibraryCounts?
    @State private var error: String?

    enum LibraryTab: String, CaseIterable, Identifiable {
        case watching, stopped, finished
        var id: String { rawValue }
        var label: String {
            switch self {
            case .watching: return "Watching"
            case .stopped: return "Paused"
            case .finished: return "Finished"
            }
        }
        var apiTab: String {
            switch self {
            case .watching: return "watching"
            case .stopped: return "stopped"
            case .finished: return "finished"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Library", selection: $tab) {
                ForEach(LibraryTab.allCases) { t in
                    Text(tabLabel(t)).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            List {
                ForEach(items) { item in
                    NavigationLink {
                        TVDetailView(tvId: Int(item.tvId) ?? 0)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath))
                                .frame(width: 52, height: 78)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.tvTitle ?? "Show")
                                    .font(.headline)
                                    .foregroundStyle(theme.ink)
                                let progress = ShowProgress.from(track: item)
                                if tab == .finished || progress.isComplete {
                                    Text("Completed")
                                        .font(.caption)
                                        .foregroundStyle(theme.inkMuted)
                                } else {
                                    Text(progress.episodeLine)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(theme.olive)
                                    if let name = progress.next?.name, !name.isEmpty {
                                        Text(name)
                                            .font(.caption)
                                            .foregroundStyle(theme.inkMuted)
                                            .lineLimit(1)
                                    }
                                    HStack(spacing: 8) {
                                        ProgressTrack(progress: progress.fraction)
                                        Text(progress.total > 0 ? "\(progress.percent)%" : "\(progress.watched) ep")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(theme.olive)
                                            .monospacedDigit()
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(theme.surface)
                    .swipeActions(edge: .trailing) {
                        if tab == .watching {
                            Button("Pause") {
                                Task {
                                    try? await DiaryService.stopTracking(tvId: item.tvId, status: "paused")
                                    await load()
                                }
                            }
                            .tint(theme.inkMuted)
                        }
                        if tab == .stopped {
                            Button("Resume") {
                                Task {
                                    try? await DiaryService.resumeTracking(tvId: item.tvId)
                                    await load()
                                }
                            }
                            .tint(theme.accent)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .overlay {
                if items.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: "tv",
                        description: Text("Start tracking a show and it will land in this shelf.")
                    )
                }
            }
        }
        .marqueeCanvas()
        .navigationTitle("TV library")
        .onChange(of: tab) { _, _ in
            Task { await load() }
        }
        .task { await load() }
    }

    private func tabLabel(_ t: LibraryTab) -> String {
        guard let summary else { return t.label }
        switch t {
        case .watching: return "\(t.label) \(summary.watching ?? 0)"
        case .stopped: return "\(t.label) \(summary.paused ?? 0)"
        case .finished: return "\(t.label) \(summary.completed ?? 0)"
        }
    }

    private func load() async {
        do {
            summary = try await DiaryService.librarySummary().counts
            items = try await DiaryService.library(tab: tab.apiTab)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
