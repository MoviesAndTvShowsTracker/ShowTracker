import SwiftUI

// MARK: - Import prompt (Home + You, new users only)

/// TV Time closed in July 2026, so most new users arrive with years of history.
struct ImportPromptCard: View {
    @Environment(\.marqueeTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coming from TV Time?")
                .font(.title3.weight(.bold))
                .foregroundStyle(MarqueeColor.saltGrey)
            Text("Bring every show and episode you’ve logged. It takes a few minutes.")
                .font(.subheadline)
                .foregroundStyle(MarqueeColor.saltGrey.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            NavigationLink { TVTimeImportView() } label: {
                Text("Import history")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(theme.onAccent)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(theme.accent, in: Capsule())
            }
            .buttonStyle(PressablePosterStyle())
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(OlivePanel(cornerRadius: 20))
    }
}

// MARK: - Home starter

struct StarterSection: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onDone: () -> Void = {}

    @State private var shows: [MediaItem] = []
    @State private var films: [MediaItem] = []
    @State private var loading = true
    private var index: TVDiaryIndex { .shared }

    private var picked: Int { shows.filter { index.watchlist.contains($0.id) }.count }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            ImportPromptCard().padding(.horizontal, 20)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pick shows you watch")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.ink)
                    Text(picked == 0 ? "Tap a few. They’ll wait for you here." : "\(picked) picked. Add more or head in.")
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                        .contentTransition(.numericText())
                }
                LazyVGrid(columns: columns, spacing: 10) {
                    if loading {
                        ForEach(0..<9, id: \.self) { _ in
                            SkeletonBlock(height: 150, radius: 12)
                        }
                    } else {
                        ForEach(shows) { show in PickTile(item: show, picked: index.watchlist.contains(show.id)) }
                    }
                }
                if picked > 0 {
                    Button {
                        Haptics.light()
                        onDone()
                    } label: {
                        Text("Show my home")
                            .font(.headline)
                            .foregroundStyle(theme.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(theme.accent, in: Capsule())
                    }
                    .buttonStyle(PressablePosterStyle())
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 20)
            .animation(reduceMotion ? nil : MarqueeMotion.standard, value: picked)

            if !films.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Films everyone’s watching")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 20)
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(films) { item in
                                MediaNavLink(id: item.id, kind: .movie) {
                                    PosterTile(title: item.displayTitle, posterPath: item.poster_path)
                                }
                                .catalogQuickActions(item, kind: .movie)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
        .task {
            async let tv = TMDBService.fetchPaged("trending/tv/week")
            async let mv = TMDBService.fetchPaged("trending/movie/week")
            await index.refresh()
            shows = Array(((try? await tv)?.results ?? []).filter { $0.poster_path != nil }.prefix(9))
            films = Array(((try? await mv)?.results ?? []).prefix(12))
            loading = false
        }
    }
}

private struct PickTile: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let item: MediaItem
    let picked: Bool
    @State private var busy = false

    var body: some View {
        Button {
            guard !busy else { return }
            Haptics.light()
            busy = true
            Task {
                do { try await TVDiaryIndex.shared.toggleWatchlist(item) } catch { Feedback.failed("Couldn’t save that. Try again.") }
                busy = false
            }
        } label: {
            CachedAsyncImage(url: AppConfig.posterURL(path: item.poster_path))
                .aspectRatio(2 / 3, contentMode: .fill)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.black.opacity(picked ? 0.35 : 0))
                }
                .overlay(alignment: .topTrailing) {
                    Image(systemName: picked ? "checkmark" : "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(picked ? theme.onAccent : MarqueeColor.saltGrey)
                        .frame(width: 28, height: 28)
                        .background(picked ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.black.opacity(0.45)), in: Circle())
                        .padding(6)
                        .scaleEffect(picked && !reduceMotion ? 1.08 : 1)
                }
                .animation(reduceMotion ? nil : MarqueeMotion.micro, value: picked)
        }
        .buttonStyle(PressablePosterStyle())
        .accessibilityLabel(item.displayTitle)
        .accessibilityValue(picked ? "Added" : "Not added")
        .accessibilityHint("Adds to your TV watchlist")
    }
}

// MARK: - Ghost rail (You, empty diary)

/// Shows the shape of what fills in, so an empty profile still reads as a profile.
struct GhostRail<Destination: View>: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let hint: String
    @ViewBuilder var destination: () -> Destination

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Text(hint)
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(.horizontal, 20)
            NavigationLink(destination: destination) {
                HStack(spacing: 12) {
                    slot(first: true)
                    ForEach(0..<3, id: \.self) { i in slot(first: false).opacity(1 - Double(i) * 0.25) }
                }
                .padding(.horizontal, 20)
            }
            .buttonStyle(PressablePosterStyle())
            .accessibilityLabel("\(title). \(hint)")
        }
    }

    private func slot(first: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(first ? theme.oliveSoft : theme.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(theme.border, style: StrokeStyle(lineWidth: 1, dash: first ? [] : [5, 4]))
            )
            .overlay {
                if first {
                    Image(systemName: "plus").font(.title3.weight(.semibold)).foregroundStyle(theme.olive)
                }
            }
            .frame(width: 80, height: 120)
    }
}
