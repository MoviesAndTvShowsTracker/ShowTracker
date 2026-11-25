import Foundation

/// What the show page's log sheet is doing for an episode.
enum EpisodeLogTarget: Identifiable, Hashable {
    case new(TVEpisode)
    case edit(TVEpisode)

    var episode: TVEpisode {
        switch self {
        case .new(let ep), .edit(let ep): ep
        }
    }

    var id: String {
        switch self {
        case .new(let ep): "new-\(ep.diaryKey)"
        case .edit(let ep): "edit-\(ep.diaryKey)"
        }
    }
}
