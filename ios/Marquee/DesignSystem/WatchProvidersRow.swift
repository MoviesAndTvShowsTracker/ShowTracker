import SwiftUI

struct WatchProvider: Decodable, Identifiable, Hashable, Sendable {
    var id: Int { provider_id }
    let provider_id: Int
    let provider_name: String
    let logo_path: String?
}

struct WatchProviderRegion: Decodable, Sendable {
    let flatrate: [WatchProvider]?
    let ads: [WatchProvider]?
    let free: [WatchProvider]?
    let rent: [WatchProvider]?
    let buy: [WatchProvider]?

    var stream: [WatchProvider] {
        var seen = Set<Int>()
        var out: [WatchProvider] = []
        for p in (flatrate ?? []) + (free ?? []) + (ads ?? []) {
            if seen.insert(p.provider_id).inserted { out.append(p) }
        }
        return out
    }
}

struct WatchProviderResponse: Decodable, Sendable {
    let results: [String: WatchProviderRegion]?
}

enum WatchProviderService {
    static func load(kind: MediaKind, id: Int) async -> (providers: [WatchProvider], region: String?) {
        let path = kind == .movie ? "/api/tmdb/movie/\(id)/watch/providers" : "/api/tmdb/tv/\(id)/watch/providers"
        guard let res: WatchProviderResponse = try? await APIClient.shared.get(path, auth: false) else {
            return ([], nil)
        }
        let results = res.results ?? [:]
        for region in ["US", "CA", "GB"] {
            if let list = results[region]?.stream, !list.isEmpty {
                return (Array(list.prefix(8)), region)
            }
        }
        if let first = results.first, !first.value.stream.isEmpty {
            return (Array(first.value.stream.prefix(8)), first.key)
        }
        return ([], nil)
    }
}

enum WatchProviderLinks {
    static func url(for provider: WatchProvider, region: String?) -> URL {
        let query = provider.provider_name
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "stream"
        let locale = (region ?? "us").lowercased()
        if let justWatch = URL(string: "https://www.justwatch.com/\(locale)/provider/\(provider.provider_id)") {
            return justWatch
        }
        return URL(string: "https://www.justwatch.com/search?q=\(query)")!
    }
}

struct WatchProvidersRow: View {
    @Environment(\.marqueeTheme) private var theme
    let providers: [WatchProvider]
    var region: String?

    var body: some View {
        if !providers.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionKicker(text: "Where to watch")
                    Spacer()
                    if let region {
                        Text(region == "CA" ? "Canada" : region == "US" ? "United States" : region)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(providers) { p in
                            Link(destination: WatchProviderLinks.url(for: p, region: region)) {
                                VStack(spacing: 6) {
                                    CachedAsyncImage(url: AppConfig.posterURL(path: p.logo_path, size: "w92"))
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                                    Text(p.provider_name)
                                        .font(.caption2)
                                        .foregroundStyle(theme.inkMuted)
                                        .lineLimit(1)
                                        .frame(width: 52)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
