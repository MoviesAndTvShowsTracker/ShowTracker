import SwiftUI

struct RatingsStrip: View {
    @Environment(\.marqueeTheme) private var theme
    let ratings: MediaRatings?
    var isLoading: Bool = false

    var body: some View {
        if isLoading {
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(height: 12, width: 72)
                HStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonBlock(height: 56, radius: 14)
                    }
                }
            }
            .accessibilityLabel("Loading ratings")
        } else if let ratings {
            let chips = ratings.chips
            if !chips.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionKicker(text: "Ratings")
                    HStack(spacing: 10) {
                        ForEach(chips) { chip in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chip.label)
                                    .font(.caption2.weight(.bold))
                                    .tracking(0.6)
                                    .textCase(.uppercase)
                                    .foregroundStyle(theme.olive)
                                HStack(alignment: .firstTextBaseline, spacing: 2) {
                                    Text(chip.display)
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(theme.ink)
                                        .monospacedDigit()
                                    if let detail = chip.detail {
                                        Text(detail)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(theme.surfaceElevated.opacity(0.9))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(theme.border.opacity(0.8), lineWidth: 1)
                            )
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
