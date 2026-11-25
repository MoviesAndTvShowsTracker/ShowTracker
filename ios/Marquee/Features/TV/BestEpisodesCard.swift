import SwiftUI

/// "Your best episodes": the top-rated episodes of a show, from your own ratings.
struct BestEpisodesCard: View {
    @Environment(\.marqueeTheme) private var theme
    let entries: [EpisodeRatingsSummary.Entry]
    let onSelect: (EpisodeRatingsSummary.Entry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionKicker(text: "Your best episodes")
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.key) { index, entry in
                    if index > 0 { Divider().overlay(theme.border).padding(.leading, 14) }
                    Button { onSelect(entry) } label: {
                        HStack(spacing: 12) {
                            Text(entry.label)
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(theme.olive)
                                .frame(minWidth: 52, alignment: .leading)
                            Text(entry.name ?? "Episode \(entry.episode)")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(theme.ink)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            StarRatingView(rating: .constant(entry.stars), editable: false, size: .caption)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(entry.label), \(entry.name ?? "Episode \(entry.episode)"), rated \(String(format: "%g", entry.stars)) of 5")
                    .accessibilityAddTraits(.isButton)
                }
            }
            .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(theme.border, lineWidth: 1))
        }
    }
}
