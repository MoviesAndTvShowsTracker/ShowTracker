import SwiftUI

/// "Your watches": every dated watch of a film, newest first, each one editable.
struct FilmWatchesSection: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let plays: [FilmPlay]
    let onEdit: (FilmPlay) -> Void

    @State private var showAll = false
    private let collapsedCount = 3

    private var visible: [FilmPlay] { showAll ? plays : Array(plays.prefix(collapsedCount)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: plays.count == 1 ? "Your watch" : "Your watches")

            VStack(spacing: 0) {
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, play in
                    if index > 0 {
                        Divider().overlay(theme.border).padding(.leading, 74)
                    }
                    FilmWatchRow(play: play, isFirst: !(play.isRewatch ?? false)) { onEdit(play) }
                        .transition(.opacity)
                }
            }
            .background(theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.border, lineWidth: 1))

            if plays.count > collapsedCount {
                Button(showAll ? "Show fewer" : "Show all \(plays.count) watches") {
                    withAnimation(reduceMotion ? nil : MarqueeMotion.standard) { showAll.toggle() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.olive)
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FilmWatchRow: View {
    @Environment(\.marqueeTheme) private var theme
    let play: FilmPlay
    let isFirst: Bool
    let onTap: () -> Void

    private var date: Date? { play.date }

    private var heading: String {
        let kind = isFirst ? "First watch" : "Rewatch"
        guard let date, !Calendar.current.isDate(date, equalTo: .now, toGranularity: .year) else { return kind }
        return "\(kind) · \(date.formatted(.dateTime.year()))"
    }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                DiaryDateTile(date: date)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(heading)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.ink)
                        Spacer(minLength: 8)
                        if play.stars > 0 {
                            StarRatingView(rating: .constant(play.stars), editable: false, size: .caption)
                        }
                    }
                    if let note = play.noteText {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(theme.inkMuted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    } else {
                        Label("Add a note", systemImage: "plus.circle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.olive)
                    }
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.olive)
                    .padding(.top, 4)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("Edit date and note")
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityText: String {
        var parts = [isFirst ? "First watch" : "Rewatch"]
        if let date { parts.append(date.formatted(date: .long, time: .omitted)) }
        if play.stars > 0 { parts.append("rated \(String(format: "%g", play.stars)) of 5") }
        if let note = play.noteText { parts.append("note: \(note)") }
        return parts.joined(separator: ", ")
    }
}

/// A small calendar leaf: month over day, in the diary's olive.
struct DiaryDateTile: View {
    @Environment(\.marqueeTheme) private var theme
    let date: Date?

    var body: some View {
        VStack(spacing: 0) {
            Text(date.map { $0.formatted(.dateTime.month(.abbreviated)) } ?? "—")
                .font(.caption2.weight(.bold))
                .tracking(MarqueeType.labelTracking)
                .textCase(.uppercase)
                .foregroundStyle(theme.olive)
            Text(date.map { $0.formatted(.dateTime.day()) } ?? "")
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(theme.ink)
        }
        .frame(width: 46, height: 50)
        .background(theme.oliveSoft, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .accessibilityHidden(true)
    }
}
