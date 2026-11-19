import Foundation

enum AppConfig {
    static var apiBaseURL: URL {
        if let override = UserDefaults.standard.string(forKey: "apiBaseURL"),
           let url = URL(string: override), !override.isEmpty {
            return url
        }
        if let env = envValue("API_BASE_URL"), let url = URL(string: env) {
            return url
        }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: plist), !plist.isEmpty {
            return url
        }
        return URL(string: "https://marquee-4kjw.onrender.com")!
    }

    static var googleWebClientID: String {
        if let env = envValue("GOOGLE_CLIENT_ID"), !env.isEmpty { return env }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "GIDServerClientID") as? String,
           !plist.isEmpty {
            return plist
        }
        return ""
    }

    static var googleIOSClientID: String {
        if let env = envValue("GOOGLE_IOS_CLIENT_ID"), !env.isEmpty { return env }
        if let plist = googleServiceInfo["CLIENT_ID"], !plist.isEmpty { return plist }
        if let plist = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
           !plist.isEmpty {
            return plist
        }
        return googleWebClientID
    }

    static var googleClientID: String { googleIOSClientID }

    static var googleURLScheme: String {
        if let reversed = googleServiceInfo["REVERSED_CLIENT_ID"], !reversed.isEmpty {
            return reversed
        }
        let trimmed = googleIOSClientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(trimmed)"
    }

    /// Legal pages are hosted on the API (also mirrored on the web app).
    static var privacyURL: URL { apiBaseURL.appending(path: "privacy.html") }
    static var termsURL: URL { apiBaseURL.appending(path: "terms.html") }
    static var tmdbAttributionURL: URL { URL(string: "https://www.themoviedb.org/")! }
    static var feedbackEmail: URL { URL(string: "mailto:jprajapati2014@gmail.com?subject=Marquee%20Feedback")! }
    static var appStoreURL: URL { URL(string: "https://apps.apple.com/app/id0000000000")! }

    static let tmdbImageBase = URL(string: "https://image.tmdb.org/t/p/")!

    static func posterURL(path: String?, size: String = "w342") -> URL? {
        guard let path, !path.isEmpty else { return nil }
        return tmdbImageBase.appendingPathComponent(size).appendingPathComponent(String(path.drop(while: { $0 == "/" })))
    }

    static func backdropURL(path: String?, size: String = "w780") -> URL? {
        posterURL(path: path, size: size)
    }

    private static let googleServiceInfo: [String: String] = {
        guard let url = Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: Any] else {
            return [:]
        }
        var values: [String: String] = [:]
        for (key, value) in dict {
            if let string = value as? String { values[key] = string }
        }
        return values
    }()

    private static let envFile: [String: String] = {
        guard let url = bundledEnvURL(),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return [:]
        }
        var values: [String: String] = [:]
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { continue }
            let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let value = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
            values[key] = value
        }
        return values
    }()

    private static func bundledEnvURL() -> URL? {
        let candidates: [URL?] = [
            Bundle.main.url(forResource: ".env", withExtension: nil),
            Bundle.main.url(forResource: "", withExtension: "env"),
            Bundle.main.resourceURL?.appendingPathComponent(".env"),
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    private static func envValue(_ key: String) -> String? {
        ProcessInfo.processInfo.environment[key] ?? envFile[key]
    }
}
