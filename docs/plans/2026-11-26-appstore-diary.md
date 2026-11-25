# App Store readiness + diary dates, notes, export — execution

Branch: `feature/diary-dates-notes`. Design rules: ios/DESIGN.md (Lobby Light, hibiscus = actions only, glass on chrome only, springs 100–250 ms, Reduce Motion), skills: apple-design, mobile-ios-design, swiftui-pro.
Suites: backend `for f in backend-server/scripts/test-*.js; do node $f || exit 1; done`; iOS MarqueeTests.

## Task 1 (server): watch dates and notes
- lib/diaryInput.js: parseWatchedAt (default now; reject invalid, future > now+36h for time zones, before 1900), parseNote (≤ 500 chars, trimmed, '' clears).
- Films: addToWatch accepts watchedAt + note; rewatch flags recomputed by date order; POST /api/watch/play/update {playId, watchedAt?, note?}; watched summary returns plays [{id, watchedAt, note, rating, isRewatch}].
- Episodes: note on TvEpisodeWatch; /mark accepts watchedAt + note; POST /api/tv/episodes/update {tvId, seasonNumber, episodeNumber, watchedAt?, note?}.
- Every write invalidates stats. Tests: test-diary-input.js, test-rewatch-flags.js.

## Task 2 (server): export
- GET /api/diary/export?format=json|csv: films, episodes, rewatch episodes, shows, watchlists, favorites; CSV diary rows with formula-injection guard. Test: test-diary-export.js.

## Task 3 (server): ratings without scraping
- Remove Rotten Tomatoes page download; RT value only from OMDb's Ratings array.

## Task 4 (iOS): privacy manifests
- PrivacyInfo.xcprivacy in app (UserDefaults CA92.1 + 1C8F.1, collected data types, no tracking) and widget (1C8F.1).

## Task 5 (iOS): ratings strip as plain text + TMDB logo in About

## Task 6 (iOS): Log details sheet (shared), DateChoice model (tested), note limit

## Task 7 (iOS): film integration — quick log stays; "Log with date & note…"; Your diary list with edit

## Task 8 (iOS): episode integration — context menu, edit, note line, "Mark watched up to here"

## Task 9 (iOS): Export my diary in Settings (JSON/CSV share sheet)
