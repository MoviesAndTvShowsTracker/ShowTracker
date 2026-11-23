import Foundation

enum PersonFilmographySegment: String, CaseIterable, Identifiable, Hashable {
    case knownFor
    case acting
    case directing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .knownFor: return "Known for"
        case .acting: return "Acting"
        case .directing: return "Directing"
        }
    }
}

enum PersonCreditsProcessor {
    private static let selfRoles: Set<String> = [
        "self", "himself", "herself", "themself", "themselves",
    ]

    static func acting(from credits: PersonCombinedCredits?) -> [PersonCredit] {
        dedupe(filterNoise(credits?.cast ?? []))
            .sorted(by: dateDescending)
    }

    static func directing(from credits: PersonCombinedCredits?) -> [PersonCredit] {
        let crew = (credits?.crew ?? []).filter { credit in
            let job = credit.job ?? ""
            return job == "Director" || job == "Creator"
        }
        return dedupe(filterNoise(crew)).sorted(by: dateDescending)
    }

    /// TMDB guidance: filter by known_for_department, sort by vote_count, take top N.
    static func knownFor(person: PersonDetail, credits: PersonCombinedCredits?, limit: Int = 12) -> [PersonCredit] {
        let department = (person.known_for_department ?? "").lowercased()
        let actingList = acting(from: credits)
        let directingList = directing(from: credits)

        let pool: [PersonCredit]
        if department.contains("direct") {
            pool = directingList.isEmpty ? actingList : directingList
        } else if department.contains("act") || department.isEmpty {
            pool = actingList.isEmpty ? directingList : actingList
        } else {
            // Writing / Production / etc. — prefer cast, fall back to directing slice.
            pool = actingList.isEmpty ? directingList : actingList
        }

        // Prefer billed roles with posters; vote_count alone elevates talk-show catalog noise.
        let ranked = pool.sorted { lhs, rhs in
            let lp = lhs.poster_path == nil
            let rp = rhs.poster_path == nil
            if lp != rp { return !lp }
            let lv = lhs.vote_count ?? 0
            let rv = rhs.vote_count ?? 0
            if lv != rv { return lv > rv }
            return dateDescending(lhs, rhs)
        }
        return Array(ranked.prefix(limit))
    }

    static func availableSegments(person: PersonDetail, credits: PersonCombinedCredits?) -> [PersonFilmographySegment] {
        var out: [PersonFilmographySegment] = []
        let known = knownFor(person: person, credits: credits)
        let act = acting(from: credits)
        let dir = directing(from: credits)
        if !known.isEmpty { out.append(.knownFor) }
        if !act.isEmpty { out.append(.acting) }
        if !dir.isEmpty { out.append(.directing) }
        return out
    }

    static func credits(
        for segment: PersonFilmographySegment,
        person: PersonDetail,
        credits: PersonCombinedCredits?
    ) -> [PersonCredit] {
        switch segment {
        case .knownFor: return knownFor(person: person, credits: credits)
        case .acting: return acting(from: credits)
        case .directing: return directing(from: credits)
        }
    }

    // MARK: - Filters

    private static func filterNoise(_ items: [PersonCredit]) -> [PersonCredit] {
        items.filter { credit in
            if credit.isAdult { return false }
            if isAppearanceNoise(credit.character) { return false }
            return true
        }
    }

    /// Talk-show / archival “Self”, “Self - Guest”, “Himself”, etc.
    private static func isAppearanceNoise(_ character: String?) -> Bool {
        guard let raw = character?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return false
        }
        let lower = raw.lowercased()
        // Split billing aliases: "Self / Host"
        let parts = lower
            .split(whereSeparator: { $0 == "/" || $0 == "|" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        for part in parts {
            let head = part.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
                .first
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } ?? part
            if selfRoles.contains(head) || selfRoles.contains(part) { return true }
            if part.hasPrefix("self ") || part.hasPrefix("self-") { return true }
            if part.contains("guest") && (part.contains("self") || part == "guest") { return true }
        }
        return false
    }

    private static func dedupe(_ items: [PersonCredit]) -> [PersonCredit] {
        var seen = Set<String>()
        var out: [PersonCredit] = []
        for item in items {
            let key = "\(item.media_type ?? "movie")-\(item.id)"
            if seen.insert(key).inserted {
                out.append(item)
            }
        }
        return out
    }

    private static func dateDescending(_ a: PersonCredit, _ b: PersonCredit) -> Bool {
        let da = a.dateKey
        let db = b.dateKey
        if da.isEmpty != db.isEmpty { return !da.isEmpty }
        return da > db
    }
}
