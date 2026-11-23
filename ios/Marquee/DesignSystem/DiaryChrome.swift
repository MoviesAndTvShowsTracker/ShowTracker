import SwiftUI

/// Compact diary status used on posters (person credits, search results).
enum DiaryStatusMark: Equatable {
    case watched(times: Int)
    case watchlist

    static var watched: DiaryStatusMark { .watched(times: 1) }

    var systemImage: String {
        switch self {
        case .watched: return "eye.fill"
        case .watchlist: return "bookmark.fill"
        }
    }

    var watchTimes: Int {
        switch self {
        case .watched(let times): return max(1, times)
        case .watchlist: return 0
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .watched(let times) where times > 1:
            return "Watched \(times) times"
        case .watched:
            return "Watched"
        case .watchlist:
            return "On watchlist"
        }
    }
}

struct DiaryStatusBadge: View {
    @Environment(\.marqueeTheme) private var theme
    let mark: DiaryStatusMark
    var compact: Bool = false

    var body: some View {
        Group {
            if case .watched(let times) = mark, times > 1 {
                Text("×\(times)")
                    .font((compact ? Font.caption2 : Font.caption).weight(.bold))
                    .foregroundStyle(theme.olive)
                    .padding(.horizontal, compact ? 6 : 7)
                    .padding(.vertical, compact ? 5 : 6)
                    .background(.ultraThinMaterial, in: Capsule())
            } else {
                Image(systemName: mark.systemImage)
                    .font((compact ? Font.caption2 : Font.caption).weight(.bold))
                    .foregroundStyle(theme.olive)
                    .padding(compact ? 6 : 7)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .accessibilityLabel(mark.accessibilityLabel)
    }
}

struct DiaryChipLabel: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let systemImage: String
    var subtitle: String? = nil
    var active: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .symbolEffect(.bounce, value: active)
            Text(title)
                .lineLimit(1)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(active ? theme.accent.opacity(0.85) : theme.olive.opacity(0.9))
                    .lineLimit(1)
            }
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(active ? theme.accent : theme.olive)
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(active ? theme.accent.opacity(0.16) : theme.surface.opacity(0.88))
        .overlay(
            Capsule()
                .stroke(active ? theme.accent.opacity(0.45) : theme.border, lineWidth: 1)
        )
        .clipShape(Capsule())
        .fixedSize()
        .shadow(color: active ? theme.accent.opacity(0.12) : .clear, radius: 8, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? title)
    }
}

struct ActionStripButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let title: String
    let systemImage: String
    var subtitle: String? = nil
    var active: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            DiaryChipLabel(title: title, systemImage: systemImage, subtitle: subtitle, active: active)
        }
        .buttonStyle(PressablePosterStyle())
        .fixedSize()
        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: active)
        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: subtitle)
    }
}

struct MetaCell: View {
    @Environment(\.marqueeTheme) private var theme
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(theme.olive)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.oliveSoft)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct ProgressTrack: View {
    @Environment(\.marqueeTheme) private var theme
    var progress: Double
    var completed: Bool = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.border)
                Capsule()
                    .fill(completed ? theme.olive : theme.accent)
                    .frame(width: fillWidth(in: geo.size.width))
            }
        }
        .frame(height: 6)
    }

    private func fillWidth(in total: CGFloat) -> CGFloat {
        let clamped = min(max(progress, 0), 1)
        if clamped <= 0 { return 0 }
        return max(6, total * clamped)
    }
}

struct EmptyDiaryCard: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let message: String
    var chip: String = "Lobby"
    var cta: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                OliveChip(text: chip)
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.ink)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                if let cta, let action {
                    Button(cta, action: action)
                        .buttonStyle(PrimaryButtonStyle())
                        .padding(.top, 4)
                }
            }
        }
    }
}
