import Foundation
import Observation

/// Up next list state: one-tap mark, undo of the latest mark, toast.
@MainActor
@Observable
final class UpNextModel {
    struct Toast: Equatable {
        let id = UUID()
        let title: String
    }

    private(set) var items: [UpNextItem]
    private(set) var marking: Set<String> = []
    private(set) var justMarked: Set<String> = []
    var toast: Toast?
    var errorMessage: String?

    @ObservationIgnored private let markAction: (TrackingRecord) async throws -> EpisodeMarker.Result
    @ObservationIgnored private let undoAction: (MarkEpisodeBody) async throws -> Void
    @ObservationIgnored var onChange: () -> Void
    @ObservationIgnored private var lastMark: (index: Int, item: UpNextItem, body: MarkEpisodeBody)?

    init(
        items: [UpNextItem] = [],
        mark: @escaping (TrackingRecord) async throws -> EpisodeMarker.Result,
        undo: @escaping (MarkEpisodeBody) async throws -> Void,
        onChange: @escaping () -> Void = {}
    ) {
        self.items = items
        self.markAction = mark
        self.undoAction = undo
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
            toast = Toast(title: "Logged \(item.track.tvTitle ?? "show") S\(body.seasonNumber)E\(body.episodeNumber)")
            flashCheck(item.id)
            onChange()
        } catch {
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
        TrackingRecord(
            tvId: t.tvId, status: t.status, tvTitle: t.tvTitle, tvPosterImage: t.tvPosterImage, tvPost: t.tvPost,
            rating: t.rating, nextSeason: body.nextSeason, nextEpisode: body.nextEpisode,
            nextEpisodeName: body.nextEpisodeName, lastSeason: body.seasonNumber, lastEpisode: body.episodeNumber,
            watchedEpisodeCount: (t.watchedEpisodeCount ?? 0) + 1, totalEpisodes: t.totalEpisodes,
            airedEpisodeCount: t.airedEpisodeCount, timesCompleted: t.timesCompleted,
            activeRewatchSessionId: t.activeRewatchSessionId
        )
    }
}
