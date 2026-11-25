import Foundation

enum ProfileEdit {
    /// The server asks for the current password only when the email really changes.
    static func needsPassword(original: String, edited: String) -> Bool {
        normalized(original) != normalized(edited)
    }

    private static func normalized(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
