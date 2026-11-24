import SwiftUI
import UIKit

actor ImageCache {
    static let shared = ImageCache()

    private let memory = NSCache<NSURL, UIImage>()
    private let session: URLSession

    init() {
        let cache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024,
            diskPath: "marquee.image-cache"
        )
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .returnCacheDataElseLoad
        session = URLSession(configuration: config)
        memory.countLimit = 300
        memory.totalCostLimit = 64 * 1024 * 1024
    }

    func image(for url: URL) async -> UIImage? {
        if let cached = memory.object(forKey: url as NSURL) {
            return cached
        }
        do {
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else { return nil }
            memory.setObject(image, forKey: url as NSURL, cost: data.count)
            return image
        } catch {
            return nil
        }
    }

    func clear() {
        memory.removeAllObjects()
        session.configuration.urlCache?.removeAllCachedResponses()
    }
}

struct CachedAsyncImage: View {
    let url: URL?
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if failed || url == nil {
                Rectangle()
                    .fill(MarqueeColor.deepOlive.opacity(0.12))
                    .overlay {
                        Image(systemName: "film")
                            .foregroundStyle(MarqueeColor.deepOlive.opacity(0.35))
                    }
            } else {
                Rectangle()
                    .fill(MarqueeColor.deepOlive.opacity(0.08))
                    .overlay { ProgressView().tint(MarqueeColor.oliveLeaf) }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
        .task(id: url) {
            guard let url else { return }
            failed = false
            image = await ImageCache.shared.image(for: url)
            if image == nil { failed = true }
        }
    }
}
