import SwiftUI

actor WatchlistProviderFilter {
    private var cache: [String: Set<Int>] = [:]

    func providerIds(kind: MediaKind, id: Int) async -> Set<Int> {
        let key = "\(kind == .movie ? "movie" : "tv"):\(id)"
        if let cached = cache[key] { return cached }
        let region = await MainActor.run { () -> String in
            // Locale fallback when preferences aren't in scope.
            if let region = Locale.current.region?.identifier, region.count == 2 {
                return region.uppercased()
            }
            return "US"
        }
        let loaded = await WatchProviderService.load(kind: kind, id: id, preferredRegion: region)
        let ids = Set(loaded.providers.map(\.provider_id))
        cache[key] = ids
        return ids
    }

    func matches(
        kind: MediaKind,
        id: Int,
        preferred: Set<Int>
    ) async -> Bool {
        guard !preferred.isEmpty else { return true }
        let aliases = preferred.reduce(into: Set<Int>()) { partial, raw in
            if let option = StreamingProviderOption(rawValue: raw) {
                partial.formUnion(option.aliases)
            } else {
                partial.insert(raw)
            }
        }
        let ids = await providerIds(kind: kind, id: id)
        // Unknown / failed provider lookup — don’t hide the title.
        if ids.isEmpty { return true }
        return !ids.isDisjoint(with: aliases)
    }
}

enum StreamingProviderOption: Int, CaseIterable, Identifiable, Hashable {
    case netflix = 8
    case prime = 119
    case disney = 337
    case max = 1899
    case hulu = 15
    case appleTV = 350
    case paramount = 531

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .netflix: return "Netflix"
        case .prime: return "Prime"
        case .disney: return "Disney+"
        case .max: return "Max"
        case .hulu: return "Hulu"
        case .appleTV: return "Apple TV+"
        case .paramount: return "Paramount+"
        }
    }

    /// TMDB watch-provider logo (stable enough for a curated short list).
    var logoPath: String {
        switch self {
        case .netflix: return "/rK1KljqmbvO9HQa1PBFLILWah72.png"
        case .prime: return "/gMZdpavHmxFNnLpMHwVxfqeux2g.png"
        case .disney: return "/5eZ872CghnHFLB1j8grszbrx0dx.png"
        case .max: return "/skypuy7SXuugIQeYg0IglmzoKaS.png"
        case .hulu: return "/44uAnmSqvA4yBOdbPWN8YgQHjWm.png"
        case .appleTV: return "/v9SnyvYt0U3KGgBH3Sbh3z4yODe.png"
        case .paramount: return "/4N4BMd0Mm0kHAmF7RZgL5lW3cwc.png"
        }
    }

    /// Alternate TMDB ids that map to the same service brand.
    var aliases: Set<Int> {
        switch self {
        // TMDB uses several Amazon / Prime ids by region and storefront.
        case .prime: return [9, 10, 119, 2100, 582]
        case .max: return [1899, 1825, 31]
        case .paramount: return [531, 2303, 2616, 633]
        default: return [rawValue]
        }
    }
}

/// JustWatch-style WatchBar: icon tiles, not finicky text capsules.
struct StreamingFilterBar: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var selected: Set<Int>
    var showLabels: Bool = false

    private let iconSize: CGFloat = 40

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                anyServiceButton
                ForEach(StreamingProviderOption.allCases) { option in
                    providerButton(option)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
        .accessibilityElement(children: .contain)
    }

    private var anyServiceButton: some View {
        let isOn = selected.isEmpty
        return Button {
            selected.removeAll()
            Haptics.light()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isOn ? theme.olive : theme.surfaceElevated)
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(isOn ? theme.onAccent : theme.olive)
                }
                .frame(width: iconSize, height: iconSize)
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isOn ? theme.olive : theme.border, lineWidth: isOn ? 2 : 1)
                }
                .shadow(color: isOn ? theme.olive.opacity(0.22) : .clear, radius: 6, y: 2)

                if showLabels {
                    Text("All")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isOn ? theme.ink : theme.inkMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Any service")
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: isOn)
    }

    private func providerButton(_ option: StreamingProviderOption) -> some View {
        let isOn = selected.contains(option.rawValue)
        return Button {
            if isOn {
                selected.remove(option.rawValue)
            } else {
                selected.insert(option.rawValue)
            }
            Haptics.light()
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    CachedAsyncImage(
                        url: AppConfig.posterURL(path: option.logoPath, size: "w92"),
                        contentMode: .fill
                    )
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .opacity(isOn || selected.isEmpty ? 1 : 0.42)
                    .saturation(isOn || selected.isEmpty ? 1 : 0.35)

                    if isOn {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(theme.olive, lineWidth: 2.5)
                        VStack {
                            HStack {
                                Spacer(minLength: 0)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .symbolRenderingMode(.palette)
                                    .foregroundStyle(.white, theme.olive)
                                    .offset(x: 4, y: -4)
                            }
                            Spacer(minLength: 0)
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(theme.border.opacity(0.7), lineWidth: 1)
                    }
                }
                .frame(width: iconSize, height: iconSize)
                .shadow(color: isOn ? theme.olive.opacity(0.2) : .clear, radius: 6, y: 2)
                .scaleEffect(isOn ? 1.04 : 1)

                if showLabels {
                    Text(option.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(isOn ? theme.ink : theme.inkMuted)
                        .lineLimit(1)
                        .frame(width: iconSize + 8)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: isOn)
        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: selected.isEmpty)
    }
}
