import SwiftUI

struct RatingsStrip: View {
    @Environment(\.marqueeTheme) private var theme
    let ratings: MediaRatings?
    var isLoading: Bool = false

    var body: some View {
        if isLoading {
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(height: 11, width: 64)
                // Same shape as the loaded row (label over figure), so nothing jumps when scores arrive.
                HStack(spacing: 29) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 6) {
                            SkeletonBlock(height: 9, width: 44, radius: 3)
                            SkeletonBlock(height: 20, width: 38, radius: 5)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .accessibilityLabel("Loading ratings")
        } else if let ratings {
            let chips = ratings.chips
            if !chips.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionKicker(text: "Scores")
                    // Typographic, in our palette: each source named in plain text, no third-party marks.
                    // One row when it fits; otherwise two columns, so nothing truncates at any text size.
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 0) {
                            ForEach(Array(chips.enumerated()), id: \.element.id) { index, chip in
                                if index > 0 {
                                    Rectangle()
                                        .fill(theme.border)
                                        .frame(width: 1, height: 34)
                                        .padding(.horizontal, 14)
                                        .accessibilityHidden(true)
                                }
                                RatingScoreCell(chip: chip)
                                    .fixedSize()
                            }
                        }
                        Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 14) {
                            ForEach(Array(stride(from: 0, to: chips.count, by: 2)), id: \.self) { start in
                                GridRow {
                                    RatingScoreCell(chip: chips[start])
                                    if start + 1 < chips.count {
                                        RatingScoreCell(chip: chips[start + 1])
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Scores via OMDb and TMDB")
                        .font(.caption2)
                        .foregroundStyle(theme.inkMuted)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct RatingScoreCell: View {
    @Environment(\.marqueeTheme) private var theme
    let chip: RatingsChip

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(chip.source.label)
                .font(.caption2.weight(.semibold))
                .tracking(MarqueeType.labelTracking)
                .textCase(.uppercase)
                .foregroundStyle(theme.olive)
                .lineLimit(1)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(chip.display)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .monospacedDigit()
                if !chip.scaleText.isEmpty {
                    Text(chip.scaleText)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(theme.inkMuted)
                        .monospacedDigit()
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(chip.accessibilityLabel)
    }
}
