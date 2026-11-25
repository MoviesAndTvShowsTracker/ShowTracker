import SwiftUI

/// A short note, in the diary's voice. The counter only appears near the limit.
struct DiaryNoteField: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var note: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextField("What stuck with you?", text: $note, axis: .vertical)
                .font(.body)
                .foregroundStyle(theme.ink)
                .lineLimit(3...7)
                .focused(focused)
                .padding(14)
                .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(focused.wrappedValue ? theme.olive.opacity(0.45) : theme.border, lineWidth: 1)
                )
                .onChange(of: note) { _, new in
                    let clamped = DiaryNote.clamped(new)
                    if clamped != new { note = clamped }
                }
                .accessibilityLabel("Note")

            if let counter = DiaryNote.counter(for: note) {
                Text(counter)
                    .font(.caption2.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(note.count >= DiaryNote.limit ? theme.ink : theme.inkMuted)
                    .contentTransition(.numericText())
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: DiaryNote.counter(for: note) != nil)
    }
}
