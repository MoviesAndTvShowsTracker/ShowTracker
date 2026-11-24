# Home redesign (iOS) — design

Date: 2026-11-24 · Scope: `ios/Marquee/Features/Home/`, one shared marker in `Core/`, one new API route.

## Intent

Home's main job is **logging the next episode of what you're watching**, fast. Today the Home tab shows one in-progress show per screen (a paging carousel), and its pink "Continue" button only navigates — logging takes two screens. Home should let anyone (a brand-new account or someone tracking 30 shows) see everything in progress at once and log an episode in one tap, then show what's coming and what they just logged.

Marquee is general-purpose: every section must have a sensible state for zero, one, and many items.

## Goals

1. Every in-progress show visible without swiping; one-tap "mark next episode" with undo.
2. Know what's airing soon in a dated list that reads like a diary agenda.
3. See what you just logged (films and episodes) at a glance.
4. A real first-run screen for new users.
5. Home loads from one API call (Phase C), falling back to today's client-built path when the server is older.

## Non-goals

- No recommendations engine, no "For you" rail.
- No changes to the Films, TV, Search or You tabs, beyond `EpisodeMarker` being reused by `TVContinueView`.
- No web client changes.

## Anti-goals (fail even if it "works")

- Stat strip in the first viewport (DESIGN.md anti-slop rule).
- Glass on rows/posters, a second accent, pink section labels, blurred-poster mush backgrounds.
- One-tap marking an episode that hasn't aired yet.
- Marking that silently fails or can't be undone.

## Approaches considered

| | Approach | Trade-off |
|---|---|---|
| A | **Up Next list** with one-tap mark, This week agenda, Recently logged, week panel, Queue | Biggest UX win; client-only; still many TMDB calls |
| B | Keep carousel, add mark button | Smallest change; still hides all but one show |
| C | A + `GET /api/home` aggregate | Fast, one round-trip; backend work + tests |

**Picked: A, then C as the final phase.** User chose to include C. Client keeps the A path as fallback when `/api/home` returns 404.

## The page (top to bottom)

```
Hey, Jimil
3 shows waiting · Shōgun airs tonight
──────────────────────────────────────
Up next                       All 7 ›
[poster] VisionQuest            (✓)
         S1 · E5  Firewall
         ▓▓▓▓▓░░░░░ 5 of 10
[poster] Silo                   (✓)
[poster] Shōgun                 Thu
         S1 · E8 · airs Thu         (caught up, unaired → no mark)
Paused · 3                          ›
──────────────────────────────────────
This week
TONIGHT   Shōgun        S1E8 · Crimson Sky
THU 27    Severance     S2E3
SAT 29    The Bear      Season 4 returns
──────────────────────────────────────
Recently logged                Calendar ›
[poster][poster][poster][poster] →  (caption: "S1E4 · Tue", "Film · ★4")
──────────────────────────────────────
[olive panel] THIS WEEK 15h 32m · 4 films · 7 episodes   🔥2d  ›
──────────────────────────────────────
Your queue          [Films | TV]      All ›
[poster rail]
```

### 1. Header
- `Hey, {firstName}` (largeTitle bold) — unchanged.
- Subtitle is computed, short diary voice, priority order:
  1. A tracked episode airs today → `"{Show} airs tonight."`
  2. Up Next non-empty → `"{n} show(s) waiting."` (+ `" · {Show} airs tonight"` if 1 also true — join with " · ")
  3. This week non-empty → `"New episodes this week."`
  4. Queue non-empty → `"Your queue is waiting."`
  5. Else (first run) → handled by Starter state (no subtitle needed; use `"Let's start your diary."`).

### 2. Up next (the signature section)
- Source: `continueWatching()` (status `watching`/`rewatching`, server-sorted by `lastWatchedAt`).
- Shows the first **6** rows; header trailing link `All {n} ›` → `TVLibraryView(initialTab: .watching)` only when n > 6.
- Row (`UpNextRow`): 60×90 poster (cached path), title (headline, 1 line), episode line `S{s} · E{e}` + episode name (subheadline, inkMuted, 1 line), thin `ProgressTrack` + caption `"{watched} of {total}"` (omit when total == 0).
- Trailing control, one of:
  - **Mark button**: 44×44 circle, hibiscus fill, white `checkmark` SF Symbol, when the next episode is aired (air date ≤ today, or air date unknown).
  - **Air-day chip**: olive text on `oliveSoft` capsule (`"Tonight"`, `"Thu"`, `"Dec 3"`), no button, when the next episode's air date is in the future.
  - **Chevron** only, for `status == "rewatching"` (rewatch marking stays in TV detail, which already handles sessions).
- Tapping the row body (not the button) → `TVContinueView(tvId:seed:catalogTotal:)` (rewatching → `TVDetailView`).
- **Mark flow** (`EpisodeMarker`, see below):
  1. Button press: haptic light, button shows `ProgressView` (tint white), disabled.
  2. Success: `Haptics.success()`, button morphs to a filled checkmark for 0.6 s (`MarqueeMotion.micro`, Reduce Motion → no scale), then the row updates in place to the new next episode. If the show is now finished, the row is removed with `.transition(.opacity.combined(with: .move(edge: .leading)))` (Reduce Motion → `.opacity`).
  3. Undo toast at bottom (above tab bar): `"Logged {Show} S1E5"` + `Undo` button, auto-dismiss 5 s. Undo calls `DiaryService.unmarkEpisode` with the same body and restores the previous `TrackingRecord`. One toast at a time; a new mark replaces it (the earlier one is no longer undoable from Home).
  4. Failure: row reverts, inline error banner `"Couldn't log that. Try again."`.
  5. After success or undo: `ResponseCache` home key is cleared, recap and Recently logged are refreshed in the background (no full-screen reload).
- Paused row: under the list, a single plain row `Paused · {n} ›` → `TVLibraryView(initialTab: .stopped)` when paused count > 0. (Replaces the Paused rail.)
- Empty (but user has other data): compact card "Nothing in progress. Start a show from TV." with a `TV` button → `MediaBrowseView(kind: .tv)`.

### 3. This week (agenda)
- Next **7** days of episodes for watching + paused shows, plus season returns within **30** days for paused/finished shows. Max **8** rows; no "see all".
- Row: leading day label column (fixed width 64; caption bold, uppercase tracked, olive; `TONIGHT`/`TOMORROW`/`THU 27`), title (subheadline semibold), detail (`S1E8 · Name` or `Season 4 returns`, caption inkMuted). No posters — keeps it calm, distinct from Up Next.
- Rows sharing a day: show the day label only on the first.
- Tap → `TVDetailView(tvId:)`.
- Section hidden when empty.

### 4. Recently logged
- Source: `GET /api/diary/activity?limit=10` (existing endpoint; `DiaryActivityItem`).
- Horizontal rail of `PosterTile(width: 96)` with caption line: episodes `"S1E4 · Tue"`, films `"Film · ★4"` (rating when present) or `"Film · Tue"`. Day: `Today`/`Yesterday`/weekday abbrev within 6 days/else `Nov 3`.
- Header trailing `Calendar ›` → `DiaryActivityView()`. (Replaces the Watch calendar card; keep accessibility identifier `watch-calendar-link` on this link.)
- Tap: episode → `TVDetailView(tvId:)`, film → `MediaNavLink(id:kind:.movie)`.
- Hidden when empty.

### 5. Week panel
- Reuse `WeekPulseRow` unchanged, now placed **after** Recently logged.

### 6. Your queue
- One rail, header `Your queue` with a two-segment picker (`Films` / `TV`, `.pickerStyle(.segmented)`, fixed width 150) and `All ›` → `WatchlistView(initialScope:)` for the active segment.
- Default segment: Films if non-empty else TV. Hide the picker when only one side has items. Section hidden if both empty.
- Up to 12 `PosterTile`s, as today.

### 7. Starter (first run)
Shown when Up Next, paused, This week, Recently logged and both watchlists are all empty (after load).
- Title `"Start your diary"`, body `"Track a show and your next episode lands here, ready to log."`
- `Trending this week` rail from `TMDBService.fetchPaged("trending/tv/week")`, first 12, `MediaNavLink(kind: .tv)`.
- Two shortcut buttons (existing `LobbyEmptyState.shortcut` style): `Find a show` → Search tab equivalent `MediaBrowseView(kind: .tv)`, `Find a film` → `MediaBrowseView(kind: .movie)`.

### Loading / errors
- Cached snapshot (`ResponseCache` key `home.landing.v2`) renders immediately; skeletons only on cold start: 3 row skeletons for Up Next (`SkeletonBlock(height: 90, radius: 14)`), `RailSkeleton()` for Recently logged.
- Keep current error behaviour (full `ErrorStateView` when nothing cached, `InlineErrorBanner` otherwise).
- Pull to refresh reloads everything.

## Shared logic: `EpisodeMarker` (Core)

Extract `TVContinueView.markNext()` into `Core/EpisodeMarker.swift`:

```swift
enum EpisodeMarker {
    struct Result { let body: MarkEpisodeBody; let updated: TrackingRecord? }
    /// Marks `progress.next` for `track`, computing the following pointer via TMDB season.
    static func markNext(track: TrackingRecord, catalogTotal: Int?, runtime: Int?, episodeName: String?) async throws -> Result
    static func undo(_ body: MarkEpisodeBody) async throws
}
```
`TVContinueView.markNext()` becomes a thin call into it (behaviour identical). Home uses the same function.

## Phase C: `GET /api/home`

New route `backend-server/routes/home.js`, mounted at `/api/home`, `authenticate.verifyUser`. Logic in `backend-server/services/homeFeed.js`; pure date/schedule functions unit-tested in `backend-server/scripts/test-home-feed.js` (plain `assert`, no DB, same style as `test-tv-rewatch.js`).

Response:
```json
{
  "success": true,
  "upNext":   [TrackingRecord + "nextAirDate": "YYYY-MM-DD"|null],
  "pausedCount": 3,
  "thisWeek": [{ "tvId","title","posterPath","season","episode","episodeName","airDate","kind":"airing"|"returning" }],
  "recent":   [DiaryActivityItem shape, max 10],
  "recap":    WeekRecap,
  "watchlist": { "films": [FavoriteMovieDoc], "tv": [FavoriteTVDoc] }
}
```
- Season data: add `getTvSeason(tvId, season)` to `lib/tmdb.js` using the existing rate-limited `tmdbRequest`, but with its own **6-hour TTL** map (air dates change; the current `memoryCache` never expires).
- Caps: up to 16 upNext+paused shows for airing, 12 paused/finished for returns (same as today's client). "Today" uses `requestTimeZone(req)` (as `/api/stats/week-recap` does).
- Recent: extract the mapping in `routes/diary.js` into `services/diaryActivity.js` (`buildActivity(userId, limit)`) and reuse in both routes.
- No stats-cache invalidation needed (read-only).
- Client: `HomeService.load()` calls `/api/home`; on `APIError` 404 falls back to the Phase A client aggregation. Up Next uses `nextAirDate` from the server; in fallback it's derived by matching the schedule list.

## Cleanup

Delete unused Home code after the rebuild (verify with grep before each deletion): `TonightCard`, `TonightPicker`, `TonightPick`, `TonightKind`, `HomeRecommendation`, `ForYouRail`, `HomeShowRail`, `HomeScheduleRail`, `UpNextStrip`, `ContinueHeroCard`, `ContinueCard`, `LobbyTimelineRail`, `ThisWeekCardChrome`. Keep `StreamingFilterBar`/`StreamingProviderOption` (used by Watchlist, Browse, Settings, CatalogShelves) — move them to `WatchlistProviderFilter.swift`. Run `xcodegen generate` after adding/removing files.

## Accessibility

- Mark button: `accessibilityLabel("Mark \(show) season \(s) episode \(e) watched")`; row also exposes `.accessibilityAction(named: "Mark watched")`.
- All sizes Dynamic Type; rows grow vertically, never truncate title below 1 line at AX sizes (allow 2).
- Reduce Motion respected for the check morph and row removal.
- Hit targets ≥ 44pt.

## Constraints

- iOS 26, SwiftUI, `@Observable`, async/await; palette and glass rules from `ios/DESIGN.md`; posters only via `CachedAsyncImage`.
- Widget snapshot (`WidgetSnapshotStore.save`) and `EpisodeAlertScheduler.refresh` keep being called after load.
- UI tests: `MarqueeVisualUITests.testCaptureHomeAndCalendar` must be updated to the new structure (`home-upnext` identifier, no swipe).
- Commit messages: short imperative sentences, no Co-Authored-By trailer.

## Calls I made (check these)

- Up Next cap 6, This week cap 8 / 7 days, Recently logged 10.
- Rewatching shows get no one-tap mark (rewatch sessions are separate; TV detail handles them).
- Unaired next episode → air-day chip instead of a button.
- This week rows have no posters, to stay visually distinct from Up Next.
- Week panel moves below Recently logged.
- Paused rail collapses into one `Paused · n` row.

## Left to the builder

Exact spacings within the 20pt page gutter, skeleton details, and copy tweaks within the diary voice.
