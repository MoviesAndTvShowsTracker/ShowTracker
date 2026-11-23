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

        return Array(
            pool.sorted { ($0.vote_count ?? 0) > ($1.vote_count ?? 0) }
                .prefix(limit)
        )
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
            if credit.kind == .tv, let character = credit.character?.lowercased() {
                let first = character.split(separator: "/").first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? character
                if selfRoles.contains(first) { return false }
            }
            return true
        }
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
