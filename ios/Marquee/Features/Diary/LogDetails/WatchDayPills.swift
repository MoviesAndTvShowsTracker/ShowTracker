import SwiftUI

/// Today · Yesterday · a date. The third pill opens the calendar and then shows the chosen day.
struct WatchDayPills: View {
    @Environment(\.marqueeTheme) private var theme
    @Binding var day: WatchDay
    @Binding var calendarOpen: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { pills }
            VStack(alignment: .leading, spacing: 8) { pills }
        }
    }

    @ViewBuilder
    private var pills: some View {
        Group {
            pill("Today", selected: day == .today) {
                day = .today
                calendarOpen = false
            }
            pill("Yesterday", selected: day == .yesterday) {
                day = .yesterday
                calendarOpen = false
            }
            pill(day.isCustom ? day.label() : "Pick a date", systemImage: "calendar", selected: day.isCustom) {
                if !day.isCustom {
                    day = .custom(Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now)
                }
                calendarOpen.toggle()
            }
        }
    }

    private func pill(_ title: String, systemImage: String? = nil, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage).font(.footnote.weight(.semibold))
                }
                Text(title).lineLimit(1).fixedSize()
            }
            .font(.subheadline.weight(.semibold))
            // A single-choice control: the chosen day is solid Deep Olive, unmistakable at a glance.
            .foregroundStyle(selected ? theme.surface : theme.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(selected ? theme.olive : theme.surfaceElevated, in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(selected ? Color.clear : theme.border, lineWidth: 1)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(PressablePosterStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
