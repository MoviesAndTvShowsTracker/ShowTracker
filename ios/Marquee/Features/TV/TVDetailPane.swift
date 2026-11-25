import SwiftUI

enum TVDetailPane: String, CaseIterable, Identifiable {
    case episodes
    case info

    var id: String { rawValue }

    var title: String {
        switch self {
        case .info: return "About"
        case .episodes: return "Episodes"
        }
    }

    /// Untracked → explore Info. Already in the diary → jump to Episodes.
    static func preferred(for tracking: TrackingRecord?) -> TVDetailPane {
        guard let status = tracking?.status else { return .info }
        switch status {
        case "watching", "paused", "completed", "rewatching":
            return .episodes
        default:
            return .info
        }
    }
}

/// Native segmented switch between the episode list and the catalogue info.
struct TVDetailPaneSwitcher: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var pane: TVDetailPane
    var enabled: Bool = true
    /// When false, nothing reads as selected so the preferred tab isn't seen switching mid-load.
    var showsSelection: Bool = true

    private var selection: Binding<TVDetailPane?> {
        guard showsSelection else { return .constant(nil) }
        return Binding(
            get: { pane },
            set: { next in
                guard let next, next != pane else { return }
                Haptics.light()
                withAnimation(reduceMotion ? nil : MarqueeMotion.micro) { pane = next }
            }
        )
    }

    var body: some View {
        Picker("Show sections", selection: selection) {
            ForEach(TVDetailPane.allCases) { item in
                Text(item.title).tag(Optional(item))
            }
        }
        .pickerStyle(.segmented)
        .disabled(!enabled)
    }
}

/// Reserves first-fold space under the tab bar so diary/providers don’t shove the layout.
struct TVDetailPanePlaceholder: View {
    @Environment(\.marqueeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SkeletonBlock(height: 12, width: 118)
                    Spacer()
                    SkeletonBlock(height: 10, width: 78)
                }
                HStack(spacing: 12) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(spacing: 8) {
                            SkeletonBlock(height: 44, width: 44, radius: 10)
                            SkeletonBlock(height: 8, width: 48)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                SkeletonBlock(height: 12, width: 80)
                SkeletonBlock(height: 16)
                SkeletonBlock(height: 16)
                SkeletonBlock(height: 16)
                SkeletonBlock(height: 16, width: 200)
            }

            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    HStack(spacing: 12) {
                        SkeletonBlock(height: 28, width: 28, radius: 14)
                        SkeletonBlock(height: 56, width: 100, radius: 8)
                        VStack(alignment: .leading, spacing: 8) {
                            SkeletonBlock(height: 14, width: index == 0 ? 180 : 150)
                            SkeletonBlock(height: 10, width: 96)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                    if index < 3 {
                        Rectangle()
                            .fill(theme.border)
                            .frame(height: 1)
                            .padding(.leading, 40)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(theme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            )
        }
        .accessibilityLabel("Loading show details")
    }
}

/// Same footprint as the header's action row (untracked case), so nothing jumps.
struct TVDetailDiaryChromePlaceholder: View {
    var body: some View {
        HStack(spacing: 10) {
            SkeletonBlock(height: 50, radius: 14)
            SkeletonBlock(height: 50, width: 50, radius: 25)
            SkeletonBlock(height: 50, width: 50, radius: 25)
        }
        .accessibilityLabel("Loading tracking")
    }
}
