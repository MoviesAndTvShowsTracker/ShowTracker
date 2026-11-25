import SwiftUI

/// You → Your notes: everything you've written about films and episodes, newest first.
struct NotesJournalView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var query = ""
    @State private var entries: [DiaryNoteEntry] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        Group {
            if loading && entries.isEmpty {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error, entries.isEmpty {
                ContentUnavailableView("Couldn't load your notes", systemImage: "exclamationmark.triangle", description: Text(error))
            } else if entries.isEmpty {
                if query.isEmpty {
                    ContentUnavailableView(
                        "No notes yet",
                        systemImage: "text.quote",
                        description: Text("Add a line when you log a film or an episode. It'll live here.")
                    )
                } else {
                    ContentUnavailableView.search(text: query)
                }
            } else {
                list
            }
        }
        .marqueeCanvas()
        .navigationTitle("Your notes")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: "Search notes and titles")
        .task(id: query) {
            // Wait for typing to pause before searching.
            if !query.isEmpty { try? await Task.sleep(for: .milliseconds(300)) }
            guard !Task.isCancelled else { return }
            await load()
        }
        .refreshable { await load() }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22, pinnedViews: []) {
                ForEach(DiaryNotesGrouping.months(entries)) { month in
                    VStack(alignment: .leading, spacing: 10) {
                        SectionKicker(text: month.title)
                        VStack(spacing: 0) {
                            ForEach(Array(month.entries.enumerated()), id: \.element.id) { index, entry in
                                if index > 0 { Divider().overlay(theme.border).padding(.leading, 74) }
                                NoteRow(entry: entry)
                            }
                        }
                        .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.border, lineWidth: 1))
                    }
                }
            }
            .padding(20)
        }
    }

    private func load() async {
        do {
            entries = try await DiaryService.notes(query: query)
            error = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

private struct NoteRow: View {
    @Environment(\.marqueeTheme) private var theme
    let entry: DiaryNoteEntry

    var body: some View {
        NavigationLink {
            if let id = Int(entry.mediaId) {
                if entry.isFilm { MovieDetailView(movieId: id) } else { TVDetailView(tvId: id) }
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                DiaryDateTile(date: entry.date)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.ink)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        if entry.stars > 0 {
                            StarRatingView(rating: .constant(entry.stars), editable: false, size: .caption)
                        }
                    }
                    if let subtitle = entry.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.olive)
                            .lineLimit(1)
                    }
                    Text(entry.note)
                        .font(.subheadline)
                        .foregroundStyle(theme.ink.opacity(0.85))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}
