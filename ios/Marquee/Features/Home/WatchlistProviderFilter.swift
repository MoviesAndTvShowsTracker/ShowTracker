import Foundation

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
