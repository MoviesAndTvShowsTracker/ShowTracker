import Foundation

enum AppConfig {
    /// Simulator / local API. Override with UserDefaults key `apiBaseURL` if needed.
    static var apiBaseURL: URL {
        if let override = UserDefaults.standard.string(forKey: "apiBaseURL"),
           let url = URL(string: override) {
            return url
        }
        #if targetEnvironment(simulator)
        return URL(string: "http://localhost:5001")!
        #else
        // Physical device → Mac on LAN. Override with UserDefaults `apiBaseURL` for production.
        return URL(string: "http://10.0.0.162:5001")!
        #endif
    }

    static let tmdbImageBase = URL(string: "https://image.tmdb.org/t/p/")!

    static func posterURL(path: String?, size: String = "w342") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return tmdbImageBase.appendingPathComponent(size).appendingPathComponent(String(path.drop(while: { $0 == "/" })))
    }

    static func backdropURL(path: String?, size: String = "w780") -> URL? {
        posterURL(path: path, size: size)
    }
}
