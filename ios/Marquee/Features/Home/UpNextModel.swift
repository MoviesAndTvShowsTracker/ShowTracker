import Foundation
import Observation

/// Up next list state: one-tap mark, undo of the latest mark, toast.
@MainActor
@Observable
final class UpNextModel {
    struct Toast: Equatable {
        let id = UUID()
        let title: String
        var finished = false
    }

    private(set) var items: [UpNextItem]
    private(set) var marking: Set<String> = []
    private(set) var justMarked: Set<String> = []
    var toast: Toast?
    var errorMessage: String?

    @ObservationIgnored private let markAction: (TrackingRecord) async throws -> EpisodeMarker.Result
    @ObservationIgnored private let undoAction: (MarkEpisodeBody) async throws -> Void
    @ObservationIgnored private let previewAction: (TrackingRecord) async -> TrackingRecord?
    @ObservationIgnored var onChange: () -> Void
    @ObservationIgnored private var lastMark: (index: Int, item: UpNextItem, body: MarkEpisodeBody)?

    init(
        items: [UpNextItem] = [],
        mark: @escaping (TrackingRecord) async throws -> EpisodeMarker.Result,
        undo: @escaping (MarkEpisodeBody) async throws -> Void,
        preview: @escaping (TrackingRecord) async -> TrackingRecord? = { _ in nil },
        onChange: @escaping () -> Void = {}
    ) {
        self.items = items
        self.markAction = mark
        self.undoAction = undo
        self.previewAction = preview
        self.onChange = onChange
    }

    func replace(_ items: [UpNextItem]) {
        guard marking.isEmpty else { return }
        self.items = items
    }

    func mark(_ item: UpNextItem) async {
        guard !marking.contains(item.id), let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        marking.insert(item.id)
        defer { marking.remove(item.id) }
        // Advance the row now; the server call confirms it (or we put it back).
        if let guess = await previewAction(item.track), let i = items.firstIndex(where: { $0.id == item.id }) {
            items[i] = UpNextItem(track: guess, nextAirDate: nil)
            flashCheck(item.id)
        }
        do {
            let result = try await markAction(item.track)
            let body = result.body
            if let i = items.firstIndex(where: { $0.id == item.id }) {
                if result.updated?.status == "completed" {
                    items.remove(at: i)
                } else {
                    items[i] = UpNextItem(
                        track: result.updated ?? advanced(item.track, by: body),
                        nextAirDate: nil
                    )
                }
            }
            lastMark = (index, item, body)
            let title = item.track.tvTitle ?? "show"
            if result.updated?.status == "completed" {
                toast = Toast(title: "Finished \(title).", finished: true)
                Haptics.success()
            } else {
                toast = Toast(title: "Logged \(title) S\(body.seasonNumber)E\(body.episodeNumber)")
            }
            if !justMarked.contains(item.id) { flashCheck(item.id) }
            onChange()
        } catch {
            if let i = items.firstIndex(where: { $0.id == item.id }) { items[i] = item }
            justMarked.remove(item.id)
            errorMessage = "Couldn’t log that. Try again."
        }
    }

    func undoLast() async {
        guard let last = lastMark else { return }
        lastMark = nil
        toast = nil
        do {
            try await undoAction(last.body)
            if let i = items.firstIndex(where: { $0.id == last.item.id }) {
                items[i] = last.item
            } else {
                items.insert(last.item, at: min(last.index, items.count))
            }
            onChange()
        } catch {
            errorMessage = "Couldn’t undo that. Try again."
        }
    }

    private func flashCheck(_ id: String) {
        justMarked.insert(id)
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            justMarked.remove(id)
        }
    }

    private func advanced(_ t: TrackingRecord, by body: MarkEpisodeBody) -> TrackingRecord {
        let watched = EpisodePointer(season: body.seasonNumber, episode: body.episodeNumber)
        let next = body.nextSeason.flatMap { season in
            body.nextEpisode.map { EpisodePointer(season: season, episode: $0, name: body.nextEpisodeName) }
        }
        return EpisodeMarker.advanced(t, watched: watched, next: next)
    }
}
