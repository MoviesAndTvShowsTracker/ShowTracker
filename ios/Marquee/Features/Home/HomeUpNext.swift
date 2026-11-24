import SwiftUI

struct UpNextSection: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let model: UpNextModel
    let pausedCount: Int
    let loading: Bool
    let today: Date

    private var visible: [UpNextItem] { Array(model.items.prefix(6)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Up next")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                if model.items.count > 6 {
                    NavigationLink("All \(model.items.count)") { TVLibraryView(initialTab: .watching) }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.olive)
                }
            }

            if loading && model.items.isEmpty {
                VStack(spacing: 10) {
                    ForEach(0..<3, id: \.self) { _ in SkeletonBlock(height: 90, radius: 14) }
                }
            } else if model.items.isEmpty {
                emptyCard
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider().overlay(theme.border).padding(.leading, 84)
                        }
                        UpNextRow(item: item, model: model, today: today)
                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .background(theme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.border, lineWidth: 1))
                .animation(reduceMotion ? nil : MarqueeMotion.standard, value: model.items.map(\.id))
            }

            if pausedCount > 0 {
                NavigationLink {
                    TVLibraryView(initialTab: .stopped)
                } label: {
                    HStack {
                        Text("Paused · \(pausedCount)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.ink)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.olive)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home-upnext")
    }

    private var emptyCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Nothing in progress.")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                Text("Start a show from TV.")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            NavigationLink { MediaBrowseView(kind: .tv) } label: {
                Text("TV")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.olive)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(theme.oliveSoft, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(theme.border, lineWidth: 1))
    }
}

private struct UpNextRow: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    let item: UpNextItem
    let model: UpNextModel
    let today: Date

    private var track: TrackingRecord { item.track }
    private var progress: ShowProgress { ShowProgress.from(track: track) }
    private var trailing: UpNextTrailing { HomeFeedLogic.trailing(for: item, today: today) }
    private var title: String { track.tvTitle ?? "Show" }

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                if trailing == .chevron {
                    TVDetailView(tvId: Int(track.tvId) ?? 0)
                } else {
                    TVContinueView(tvId: Int(track.tvId) ?? 0, seed: track)
                }
            } label: {
                rowLabel
            }
            .buttonStyle(.plain)

            trailingControl
        }
        .padding(12)
        .accessibilityActions {
            if trailing == .mark {
                Button("Mark watched") { Task { await model.mark(item) } }
            }
        }
    }

    private var rowLabel: some View {
        HStack(spacing: 12) {
            CachedAsyncImage(url: AppConfig.posterURL(path: track.posterPath))
                .frame(width: 60, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                Text(episodeLine)
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(1)
                if let caption = HomeFeedLogic.progressCaption(progress) {
                    HStack(spacing: 8) {
                        ProgressTrack(progress: progress.fraction, completed: progress.isComplete)
                            .frame(maxWidth: 140)
                        Text(caption)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(theme.olive)
                            .monospacedDigit()
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }

    private var episodeLine: String {
        guard let next = progress.next else { return progress.episodeLine }
        let code = "S\(next.season) · E\(next.episode)"
        if let name = next.name, !name.isEmpty { return "\(code)  \(name)" }
        return code
    }

    @ViewBuilder
    private var trailingControl: some View {
        switch trailing {
        case .mark:
            let busy = model.marking.contains(item.id)
            let done = model.justMarked.contains(item.id)
            Button {
                Haptics.light()
                Task { await model.mark(item) }
            } label: {
                ZStack {
                    Circle().fill(theme.accent)
                    if busy {
                        ProgressView().tint(theme.onAccent)
                    } else {
                        Image(systemName: done ? "checkmark.circle.fill" : "checkmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(theme.onAccent)
                    }
                }
                .frame(width: 44, height: 44)
                .scaleEffect(done && !reduceMotion ? 1.12 : 1)
                .animation(reduceMotion ? nil : MarqueeMotion.micro, value: done)
            }
            .buttonStyle(.plain)
            .disabled(busy)
            .accessibilityLabel("Mark \(title) season \(progress.next?.season ?? 0) episode \(progress.next?.episode ?? 0) watched")
        case .airs(let label):
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.olive)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(theme.oliveSoft, in: Capsule())
                .accessibilityLabel("Airs \(label)")
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.olive)
        }
    }
}

struct UndoToast: View {
    @Environment(\.marqueeTheme) private var theme
    let toast: UpNextModel.Toast
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(toast.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(1)
            Button("Undo", action: onUndo)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(theme.accentInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: "Undo", onUndo)
    }
}
