import Foundation

/// What the film page's log sheet is doing: a new dated log, or editing an existing one.
enum FilmLogTarget: Identifiable, Hashable {
    case new
    case edit(FilmPlay)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let play): "edit-\(play.id)"
        }
    }
}
