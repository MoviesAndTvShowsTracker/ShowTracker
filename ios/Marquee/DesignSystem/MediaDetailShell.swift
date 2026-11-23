import SwiftUI

// MARK: - Meta line (Apple TV structure — never a data grid)

struct MediaMetaLine: View {
    @Environment(\.marqueeTheme) private var theme
    let parts: [String]
    var tone: MetaTone = .onArt

    enum MetaTone {
        case onArt
        case onCanvas
    }

    var body: some View {
        let ink = tone == .onArt ? Color.white.opacity(0.88) : theme.inkMuted
        let accent = tone == .onArt ? Color.white : theme.accent

        HStack(spacing: 0) {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                if index > 0 {
                    Text(" · ")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ink.opacity(0.7))
                }
                if part.hasPrefix("★") {
                    Label {
                        Text(String(part.dropFirst()).trimmingCharacters(in: .whitespaces))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                    } icon: {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                    }
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(accent)
                } else {
                    Text(part)
                        .font(.subheadline.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(ink)
                }
            }
        }
        .lineLimit(1)
        .accessibilityElement(children: .combine)
    }

    static func parts(year: String? = nil, runtimeMinutes: Int? = nil, rating: Double? = nil, extra: [String] = []) -> [String] {
        var out: [String] = []
        if let year, !year.isEmpty { out.append(year) }
        if let runtimeMinutes { out.append(formatRuntime(runtimeMinutes)) }
        if let rating { out.append(String(format: "★ %.1f", rating)) }
        out.append(contentsOf: extra.filter { !$0.isEmpty })
        return out
    }

    /// 173 → "2h 53m", 45 → "45m", 120 → "2h"
    static func formatRuntime(_ minutes: Int) -> String {
        let clamped = max(0, minutes)
        let hours = clamped / 60
        let mins = clamped % 60
        if hours > 0, mins > 0 { return "\(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(mins)m"
    }
}

// MARK: - Credits (typographic rows, not cards)

struct CreditPersonRef: Identifiable, Hashable, Equatable {
    let id: Int
    let name: String
}

struct CreditRow: Identifiable, Hashable, Equatable {
    let id: String
    let label: String
    /// Plain text when people are not individually tappable (e.g. Writing).
    let value: String
    /// When non-empty, names render as chips → PersonView.
    var people: [CreditPersonRef] = []

    init(label: String, value: String, people: [CreditPersonRef] = []) {
        self.label = label
        self.value = value
        self.people = people
        self.id = "\(label)|\(value)|\(people.map(\.id))"
    }

    /// Stable, sorted join so Set iteration never reshuffles credit identity mid-session.
    static func joinedNames(_ names: [String], limit: Int) -> String {
        Array(Set(names.filter { !$0.isEmpty })).sorted().prefix(limit).joined(separator: ", ")
    }

    static func uniquePeople(_ crew: [CrewMember], jobs: Set<String>, limit: Int) -> [CreditPersonRef] {
        var seen = Set<Int>()
        var out: [CreditPersonRef] = []
        for member in crew where jobs.contains(member.job ?? "") {
            guard let name = member.name, !name.isEmpty, seen.insert(member.id).inserted else { continue }
            out.append(CreditPersonRef(id: member.id, name: name))
            if out.count >= limit { break }
        }
        return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

struct CreditsRows: View {
    let rows: [CreditRow]

    var body: some View {
        EquatableView(content: CreditsRowsContent(rows: rows))
    }
}

private struct CreditsRowsContent: View, Equatable {
    let rows: [CreditRow]

    nonisolated static func == (lhs: CreditsRowsContent, rhs: CreditsRowsContent) -> Bool {
        lhs.rows == rhs.rows
    }

    var body: some View {
        CreditsRowsPainted(rows: rows)
    }
}

private struct CreditsRowsPainted: View {
    @Environment(\.marqueeTheme) private var theme
    let rows: [CreditRow]

    var body: some View {
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                SectionKicker(text: "Credits")
                    .padding(.bottom, 8)

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    if index > 0 {
                        Rectangle()
                            .fill(theme.border.opacity(0.85))
                            .frame(height: 1)
                    }
                    HStack(alignment: .top, spacing: 14) {
                        Text(row.label)
                            .font(.caption2.weight(.bold))
                            .tracking(1.0)
                            .textCase(.uppercase)
                            .foregroundStyle(theme.olive)
                            .frame(width: 72, alignment: .leading)
                            .padding(.top, 10)

                        if row.people.isEmpty {
                            Text(row.value)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(theme.ink)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 10)
                        } else {
                            CreditNameChips(people: row.people)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

// MARK: - Cast rail

struct CreditNameChips: View {
    @Environment(\.marqueeTheme) private var theme
    let people: [CreditPersonRef]

    var body: some View {
        FlexiblePersonChipWrap(people: people)
    }
}

/// Simple wrapping HStack via Flow-like layout without extra deps.
private struct FlexiblePersonChipWrap: View {
    @Environment(\.marqueeTheme) private var theme
    let people: [CreditPersonRef]

    var body: some View {
        // Prefer a readable wrap: use a VStack of HStacks via ViewThatFits-less manual wrap.
        PersonChipFlowLayout(spacing: 8) {
            ForEach(people) { person in
                NavigationLink {
                    PersonView(personId: person.id)
                } label: {
                    Text(person.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(theme.oliveSoft, in: Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(PressablePosterStyle())
                .accessibilityIdentifier("personChip")
                .accessibilityLabel("\(person.name), view filmography")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PersonChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var widthUsed: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            widthUsed = max(widthUsed, x + size.width)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : widthUsed, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for sub in subviews {
            let size = sub.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}

struct MediaCastRail: View {
    @Environment(\.marqueeTheme) private var theme
    let cast: [(id: Int, name: String, character: String?, profilePath: String?)]

    var body: some View {
        if !cast.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                SectionKicker(text: "Cast")

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 14) {
                        ForEach(Array(cast.prefix(16)), id: \.id) { member in
                            NavigationLink {
                                PersonView(personId: member.id)
                            } label: {
                                CastBubble(
                                    name: member.name,
                                    character: member.character,
                                    profilePath: member.profilePath,
                                    diameter: 76
                                )
                            }
                            .buttonStyle(PressablePosterStyle())
                            .accessibilityIdentifier("castMember")
                            .accessibilityLabel("\(member.name), view filmography")
                        }
                    }
                    .padding(.trailing, 12)
                }
                .padding(.horizontal, -20)
                .padding(.leading, 20)
            }
        }
    }
}

// MARK: - Glass diary strip

struct DiaryGlassStrip<Content: View>: View {
    @Environment(\.marqueeTheme) private var theme
    var elevated: Bool = true
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "Your diary", accented: true)
            content()
        }
        .padding(elevated ? 14 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if elevated {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(theme.surfaceElevated.opacity(0.72))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(theme.border.opacity(0.7), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 20, y: 10)
            }
        }
    }
}

// MARK: - Scroll isolation

/// Only hero + compact chrome read `y`. Credits/synopsis must not rebuild every frame
/// or names ghost under the Liquid Glass tab bar.
@MainActor
@Observable
final class MediaDetailScrollState {
    var y: CGFloat = 0

    var collapse: CGFloat {
        min(1, max(0, y / 150))
    }

    var showCompactChrome: Bool { collapse > 0.55 }

    func update(offset: CGFloat) {
        let next = max(0, offset)
        guard abs(next - y) >= 0.5 else { return }
        y = next
    }
}

// MARK: - Shell

struct MediaDetailShell<Actions: View, Content: View>: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let backdropPath: String?
    let title: String
    let metaParts: [String]
    var genresLine: String? = nil
    let shareText: String
    var onBack: () -> Void
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var content: () -> Content

    /// Held in shell but `.y` is only read by hero/chrome — not by this body.
    @State private var scrollState = MediaDetailScrollState()
    @State private var appeared = false

    private let heroHeight: CGFloat = 490

    private var debugScrollTarget: String? {
        #if DEBUG
        ProcessInfo.processInfo.arguments
            .first(where: { $0.hasPrefix("-previewScrollTo=") })
            .map { String($0.dropFirst("-previewScrollTo=".count)) }
        #else
        nil
        #endif
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MediaDetailHero(
                        backdropPath: backdropPath,
                        title: title,
                        metaParts: metaParts,
                        genresLine: genresLine,
                        scrollState: scrollState,
                        appeared: appeared,
                        height: heroHeight
                    )
                    .zIndex(1)

                    // Body is a separate view that never observes scrollState.y.
                    MediaDetailBody(actions: actions, content: content)
                }
            }
            .scrollIndicators(.hidden)
            .coordinateSpace(.named("mediaDetailScroll"))
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y
            } action: { _, newValue in
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    scrollState.update(offset: newValue)
                }
            }
            .background(theme.surface.ignoresSafeArea())
            .ignoresSafeArea(edges: .top)
            .overlay(alignment: .top) {
                MediaDetailTopChrome(
                    title: title,
                    shareText: shareText,
                    scrollState: scrollState,
                    onBack: onBack
                )
            }
            .onAppear {
                guard !appeared else { return }
                if reduceMotion {
                    appeared = true
                } else {
                    withAnimation(MarqueeMotion.reveal) { appeared = true }
                }
                if debugScrollTarget == "body" || debugScrollTarget == "cast" {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        withAnimation(reduceMotion ? nil : MarqueeMotion.standard) {
                            proxy.scrollTo("detailBody", anchor: .top)
                        }
                    }
                }
            }
        }
    }
}

private struct MediaDetailBody<Actions: View, Content: View>: View {
    @ViewBuilder var actions: () -> Actions
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            actions()
                .padding(.top, -18)
                .zIndex(2)

            content()
                .id("detailBody")
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, 120)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MediaDetailHero: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let backdropPath: String?
    let title: String
    let metaParts: [String]
    let genresLine: String?
    let scrollState: MediaDetailScrollState
    let appeared: Bool
    let height: CGFloat

    var body: some View {
        let collapse = scrollState.collapse
        let scrollY = scrollState.y

        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(
                url: AppConfig.backdropURL(path: backdropPath),
                contentMode: .fill
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .offset(y: reduceMotion ? 0 : scrollY * 0.22)
            .opacity(appeared ? 1 : 0)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.52),
                        .init(color: .black.opacity(0.92), location: 0.62),
                        .init(color: .black.opacity(0.7), location: 0.72),
                        .init(color: .black.opacity(0.4), location: 0.82),
                        .init(color: .black.opacity(0.15), location: 0.92),
                        .init(color: .clear, location: 1.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(0.4),
                    Color.black.opacity(0.08),
                    .clear
                ],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.38)
            )
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .black, location: 0.0),
                        .init(color: .black, location: 0.55),
                        .init(color: .clear, location: 0.85)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.4),
                    .init(color: Color.black.opacity(0.25), location: 0.55),
                    .init(color: Color.black.opacity(0.45), location: 0.68),
                    .init(color: Color.black.opacity(0.2), location: 0.8),
                    .init(color: .clear, location: 0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .tracking(-0.4)
                    .foregroundStyle(Color.white)
                    .shadow(color: .black.opacity(0.55), radius: 16, y: 6)
                    .fixedSize(horizontal: false, vertical: true)
                    .opacity(appeared ? Double(1 - collapse) : 0)
                    .offset(y: appeared ? 0 : 14)

                if !metaParts.isEmpty {
                    MediaMetaLine(parts: metaParts, tone: .onArt)
                        .opacity(appeared ? Double(1 - collapse) : 0)
                        .offset(y: appeared ? 0 : 10)
                }

                if let genresLine, !genresLine.isEmpty {
                    Text(genresLine)
                        .font(.footnote.weight(.semibold))
                        .tracking(0.3)
                        .foregroundStyle(Color.white.opacity(0.8))
                        .lineLimit(2)
                        .opacity(appeared ? Double(1 - collapse) * 0.95 : 0)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 72)
            .frame(maxWidth: .infinity, alignment: .leading)
            .transaction { $0.animation = nil }
        }
        .frame(height: height)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(metaParts.joined(separator: ", "))")
    }
}

private struct MediaDetailTopChrome: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let shareText: String
    let scrollState: MediaDetailScrollState
    var onBack: () -> Void

    var body: some View {
        let showCompactChrome = scrollState.showCompactChrome

        VStack(spacing: 0) {
            HStack(spacing: 12) {
                GlassBackButton(action: onBack)

                if showCompactChrome {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: 0)

                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(theme.olive)
                        .frame(width: 40, height: 40)
                }
                .modifier(GlassCircleShareChrome())
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, showCompactChrome ? 10 : 0)
            .safeAreaPadding(.top)
            .background {
                if showCompactChrome {
                    Rectangle()
                        .fill(theme.surface.opacity(0.94))
                        .background(.ultraThinMaterial)
                        .ignoresSafeArea(edges: .top)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(theme.border)
                                .frame(height: 1)
                        }
                }
            }
            .animation(reduceMotion ? nil : MarqueeMotion.micro, value: showCompactChrome)
        }
    }
}

private struct GlassCircleShareChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}
