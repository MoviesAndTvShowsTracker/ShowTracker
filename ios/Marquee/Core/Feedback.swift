import SwiftUI

/// App-wide "that didn't save" signal. Any write that fails calls
/// `Feedback.failed(_:)`; `FeedbackBanner` (mounted once in RootView) shows it.
@MainActor
@Observable
final class Feedback {
    static let shared = Feedback()

    private(set) var message: String?
    private(set) var success = false
    private var dismissTask: Task<Void, Never>?

    static func failed(_ message: String) {
        shared.show(message)
    }

    /// Quiet confirmation for actions with no visible result (clearing caches, history).
    static func done(_ message: String) {
        shared.show(message, success: true)
    }

    func show(_ text: String, success: Bool = false) {
        withAnimation(MarqueeMotion.standard) {
            message = text
            self.success = success
        }
        if !success { Haptics.medium() }
        dismissTask?.cancel()
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(3.2))
            guard !Task.isCancelled else { return }
            dismiss()
        }
    }

    func dismiss() {
        withAnimation(MarqueeMotion.standard) { message = nil }
    }
}

/// Glass capsule that drops in from the top edge and leaves the same way.
struct FeedbackBanner: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var feedback = Feedback.shared

    var body: some View {
        VStack {
            if let message = feedback.message {
                HStack(spacing: 10) {
                    Image(systemName: feedback.success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .foregroundStyle(theme.olive)
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(2)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .glassEffect(.regular, in: .capsule)
                .padding(.horizontal, 24)
                .transition(.move(edge: .top).combined(with: .opacity))
                .onTapGesture { feedback.dismiss() }
                .accessibilityAddTraits(.isStaticText)
                .accessibilityLabel(message)
            }
            Spacer()
        }
        .padding(.top, 4)
        .allowsHitTesting(feedback.message != nil)
    }
}
