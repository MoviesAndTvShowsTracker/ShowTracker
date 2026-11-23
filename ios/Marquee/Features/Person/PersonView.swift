import SwiftUI

struct PersonView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let personId: Int

    @State private var person: PersonDetail?
    @State private var segment: PersonFilmographySegment = .knownFor
    @State private var segments: [PersonFilmographySegment] = []
    @State private var loading = true
    @State private var error: String?
    @State private var watchedMovieIds: Set<Int> = []
    @State private var watchlistMovieIds: Set<Int> = []
    @State private var watchedTVIds: Set<Int> = []
    @State private var watchlistTVIds: Set<Int> = []

    private var credits: PersonCombinedCredits? { person?.combined_credits }

    private var gridItems: [PersonCredit] {
        guard let person else { return [] }
        return PersonCreditsProcessor.credits(for: segment, person: person, credits: credits)
    }

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                if loading && person == nil {
                    personSkeleton
                } else if let error, person == nil {
                    ErrorStateView(message: error) {
                        Task { await load() }
                    }
                    .padding(.top, 24)
                } else if let person {
                    header(person)

                    if segments.count > 1 {
                        Picker("Credits", selection: $segment) {
                            ForEach(segments) { item in
                                Text(item.label).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: segment)
                    } else if let only = segments.first {
                        Text(only.label)
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(theme.olive)
                            .padding(.horizontal, 20)
                    }

                    if gridItems.isEmpty {
                        Text(emptyCopy)
                            .font(.subheadline)
                            .foregroundStyle(theme.inkMuted)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                    } else {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(gridItems, id: \.stableId) { credit in
                                MediaNavLink(id: credit.id, kind: credit.kind) {
                                    PersonCreditTile(
                                        credit: credit,
                                        diary: diaryMark(for: credit),
                                        showRole: segment != .knownFor
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: segment)
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 28)
        }
        .marqueeCanvas()
        .navigationTitle(person?.displayName ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("personView")
        .task { await load() }
    }

    private var emptyCopy: String {
        switch segment {
        case .knownFor: return "No standout credits yet."
        case .acting: return "No acting credits."
        case .directing: return "No directing credits."
        }
    }

    private func header(_ person: PersonDetail) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                CachedAsyncImage(url: AppConfig.posterURL(path: person.profile_path, size: "w185"))
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 6) {
                    // Nav title already carries the name; keep body focus on role + lifespan.
                    if !person.metaLine.isEmpty {
                        Text(person.metaLine)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.ink)
                    }
                    if let place = person.place_of_birth, !place.isEmpty {
                        Text(place)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(theme.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
            }

            if let bio = person.biography?.trimmingCharacters(in: .whitespacesAndNewlines), !bio.isEmpty {
                ExpandableText(text: bio, lineLimit: 3)
            }
        }
        .padding(.horizontal, 20)
    }

    private var personSkeleton: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                SkeletonBlock(height: 96, width: 96, radius: 18)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(height: 22, width: 160)
                    SkeletonBlock(height: 14, width: 100)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            SkeletonBlock(height: 32, radius: 8)
                .padding(.horizontal, 20)
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<9, id: \.self) { _ in
                    SkeletonBlock(height: 170, radius: 12)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func diaryMark(for credit: PersonCredit) -> DiaryStatusMark? {
        switch credit.kind {
        case .movie:
            if watchedMovieIds.contains(credit.id) { return .watched }
            if watchlistMovieIds.contains(credit.id) { return .watchlist }
        case .tv:
            if watchedTVIds.contains(credit.id) { return .watched }
            if watchlistTVIds.contains(credit.id) { return .watchlist }
        }
        return nil
    }

    private func load() async {
        error = nil
        loading = true
        async let personTask = TMDBService.person(id: personId)
        async let diaryTask: Void = loadDiaryMarks()

        do {
            let loaded = try await personTask
            _ = await diaryTask
            person = loaded
            let available = PersonCreditsProcessor.availableSegments(
                person: loaded,
                credits: loaded.combined_credits
            )
            segments = available
            if !available.contains(segment) {
                segment = available.first ?? .knownFor
            }
            loading = false
        } catch {
            if person == nil {
                self.error = error.localizedDescription
            }
            loading = false
        }
    }

    private func loadDiaryMarks() async {
        async let films = DiaryService.watchedMovies()
        async let filmList = DiaryService.movieWatchlist()
        async let shows = DiaryService.watchedTV()
        async let showList = DiaryService.tvWatchlist()

        if let watched = try? await films {
            watchedMovieIds = Set(watched.compactMap { Int($0.movieId) })
        }
        if let list = try? await filmList {
            watchlistMovieIds = Set(list.compactMap { Int($0.movieId) })
        }
        if let watched = try? await shows {
            watchedTVIds = Set(watched.compactMap { Int($0.tvId) })
        }
        if let list = try? await showList {
            watchlistTVIds = Set(list.compactMap { Int($0.tvId) })
        }
    }
}

private struct PersonCreditTile: View {
    @Environment(\.marqueeTheme) private var theme
    let credit: PersonCredit
    var diary: DiaryStatusMark? = nil
    var showRole: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay {
                    CachedAsyncImage(url: AppConfig.posterURL(path: credit.poster_path))
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if let diary {
                        DiaryStatusBadge(mark: diary, compact: true)
                            .padding(6)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    Text(credit.kind == .movie ? "Film" : "TV")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(6)
                }

            Text(credit.displayTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            HStack(spacing: 4) {
                if let year = credit.year {
                    Text(year)
                        .font(.caption2)
                        .foregroundStyle(theme.inkMuted)
                }
                if showRole {
                    if let character = credit.character, !character.isEmpty, credit.job == nil || segmentLooksLikeActing {
                        Text("· \(character)")
                            .font(.caption2)
                            .foregroundStyle(theme.inkMuted)
                            .lineLimit(1)
                    } else if let job = credit.job, !job.isEmpty {
                        Text("· \(job)")
                            .font(.caption2)
                            .foregroundStyle(theme.inkMuted)
                            .lineLimit(1)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var segmentLooksLikeActing: Bool {
        credit.character != nil && (credit.job == nil || credit.job?.isEmpty == true)
    }
}
