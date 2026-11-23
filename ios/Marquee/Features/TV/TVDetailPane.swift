import SwiftUI

enum TVDetailPane: String, CaseIterable, Identifiable {
    case info
    case episodes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .info: return "Info"
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

/// Editorial two-pane switcher — underline slides under the active label
/// (matched geometry), not a system segmented control.
struct TVDetailPaneSwitcher: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var pane: TVDetailPane
    var enabled: Bool = true
    /// When false, both labels stay neutral so preferred-tab commit isn’t visible mid-load.
    var showsSelection: Bool = true
    @Namespace private var underlineNS

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TVDetailPane.allCases) { item in
                paneButton(item)
            }
        }
        .padding(.bottom, 1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.border)
                .frame(height: 1)
        }
        .opacity(enabled ? 1 : 0.55)
        .allowsHitTesting(enabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Show sections")
        .respectReducedMotion()
    }

    private func paneButton(_ item: TVDetailPane) -> some View {
        let selected = showsSelection && pane == item
        return Button {
            guard enabled, pane != item else { return }
            Haptics.light()
            withAnimation(reduceMotion ? nil : MarqueeMotion.micro) {
                pane = item
            }
        } label: {
            VStack(spacing: 10) {
                Text(item.title)
                    .font(.subheadline.weight(selected ? .bold : .semibold))
                    .tracking(selected ? 0.8 : 0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(selected ? theme.ink : theme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())

                ZStack {
                    Color.clear.frame(height: 2)
                    if selected {
                        Capsule()
                            .fill(theme.accent)
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "tvDetailPaneUnderline", in: underlineNS)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(selected ? "" : "Shows \(item.title.lowercased())")
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

struct TVDetailDiaryChromePlaceholder: View {
    @Environment(\.marqueeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SkeletonBlock(height: 22, width: 88, radius: 11)
                    Spacer()
                    SkeletonBlock(height: 12, width: 52)
                }
                SkeletonBlock(height: 18, width: 160)
                SkeletonBlock(height: 12, width: 120)
                SkeletonBlock(height: 10)
                SkeletonBlock(height: 44, radius: 12)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            )

            HStack(spacing: 8) {
                SkeletonBlock(height: 38, width: 112, radius: 19)
                SkeletonBlock(height: 38, width: 100, radius: 19)
                Spacer(minLength: 0)
            }
        }
        .accessibilityLabel("Loading tracking")
    }
}
