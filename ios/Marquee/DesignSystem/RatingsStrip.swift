import SwiftUI

struct RatingsStrip: View {
    @Environment(\.marqueeTheme) private var theme
    let ratings: MediaRatings?
    var isLoading: Bool = false

    var body: some View {
        if isLoading {
            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(height: 11, width: 64)
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: 6) {
                            SkeletonBlock(height: 20, width: 20, radius: 5)
                            SkeletonBlock(height: 14, width: 26, radius: 4)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
            .accessibilityLabel("Loading ratings")
        } else if let ratings {
            let chips = ratings.chips
            if !chips.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    SectionKicker(text: "Scores")
                    // JustWatch / Plex: one calm rail — identical mark size, score beside it.
                    HStack(spacing: 0) {
                        ForEach(Array(chips.enumerated()), id: \.element.id) { index, chip in
                            if index > 0 {
                                Text("·")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(theme.inkMuted.opacity(0.45))
                                    .padding(.horizontal, 10)
                                    .accessibilityHidden(true)
                            }
                            RatingSourceCell(chip: chip)
                        }
                        Spacer(minLength: 0)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct RatingSourceCell: View {
    @Environment(\.marqueeTheme) private var theme
    let chip: RatingsChip

    var body: some View {
        HStack(spacing: 6) {
            RatingSourceMark(source: chip.source, score: chip.numericValue)
                .frame(width: 20, height: 20)
            Text(chip.display)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .monospacedDigit()
                .lineLimit(1)
        }
        .accessibilityLabel(chip.accessibilityLabel)
    }
}

/// Fixed 20×20 marks so the rail reads as one system, not four stickers.
private struct RatingSourceMark: View {
    let source: RatingSource
    let score: Double?

    var body: some View {
        switch source {
        case .imdb:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: 0xF5C518))
                .overlay {
                    Text("IMDb")
                        .font(.system(size: 6.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0x0D0D0D))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding(.horizontal, 1)
                }
        case .rottenTomatoes:
            TomatoGlyph(fresh: (score ?? 0) >= 60)
        case .metacritic:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(metascoreColor(Int(score ?? 0)))
                .overlay {
                    Text("m")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .offset(y: -0.5)
                }
        case .tmdb:
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(hex: 0x0D253F))
                .overlay {
                    Text("TMDB")
                        .font(.system(size: 5.5, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color(hex: 0x01B4E4))
                        .tracking(-0.2)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                        .padding(.horizontal, 1)
                }
        }
    }

    private func metascoreColor(_ value: Int) -> Color {
        if value >= 61 { return Color(hex: 0x66CC33) }
        if value >= 40 { return Color(hex: 0xFFCC33) }
        return Color(hex: 0xFF0000)
    }
}

private struct TomatoGlyph: View {
    let fresh: Bool

    var body: some View {
        ZStack {
            if fresh {
                // Ripe tomato — round fruit + stem leaf
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0xFF4A2E), Color(hex: 0xD42008)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Capsule()
                    .fill(Color(hex: 0x2F8F3A))
                    .frame(width: 7, height: 3.5)
                    .offset(y: -7.5)
                // Specular
                Ellipse()
                    .fill(.white.opacity(0.35))
                    .frame(width: 5, height: 3)
                    .offset(x: -3, y: -2.5)
            } else {
                RottenSplatShape()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x8BD45A), Color(hex: 0x5AA82E)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}

private struct RottenSplatShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) * 0.38
        for i in 0..<10 {
            let angle = Double(i) / 10.0 * .pi * 2 - .pi / 2
            let bulge = i.isMultiple(of: 2) ? 1.22 : 0.68
            let p = CGPoint(
                x: c.x + cos(angle) * r * bulge,
                y: c.y + sin(angle) * r * bulge
            )
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }
}
