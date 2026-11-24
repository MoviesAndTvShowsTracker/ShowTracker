# Home Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the iOS Home tab around a one-tap "Up next" list, a dated "This week" agenda, "Recently logged", the week panel, a single queue rail, and a first-run starter. Then serve it all from one `GET /api/home` call, with a client fallback.

**Architecture:** Pure, unit-tested logic (`HomeFeedLogic`, `UpNextModel`, `EpisodeMarker.following`) sits under thin SwiftUI section views. `HomeService` builds a `HomeFeed` value either from `/api/home` (Phase C) or from today's separate calls (Phase A fallback). The backend adds `services/homeFeed.js` (pure schedule math, assert-tested) and `routes/home.js`.

**Tech Stack:** SwiftUI (iOS 26, `@Observable`, async/await), XCTest (`MarqueeTests` target), Express + Mongoose, plain Node `assert` scripts.

**Spec:** `docs/superpowers/specs/2026-11-24-home-redesign-design.md`. Read it before starting; it has the page sketch and the copy.

## Global Constraints

- Palette is locked: `theme.accent` (hibiscus) is only for the mark button fill, `ProgressTrack`, and the streak pill. Labels and chips use `theme.olive`/`theme.oliveSoft`. No second accent, no pink section labels.
- No Liquid Glass on rows or posters. The undo toast is chrome, so `.glassEffect(.regular, in: Capsule())` is allowed there only.
- Posters only via `CachedAsyncImage(url: AppConfig.posterURL(path:))`, never `AsyncImage`.
- Motion: `MarqueeMotion.micro`/`.standard` only. Check `@Environment(\.accessibilityReduceMotion)` and drop scale/move when it is true.
- SF Pro only. Uppercase labels use `.tracking(MarqueeType.labelTracking)`.
- Page gutter is 20pt horizontal. Sections are spaced 26pt apart (the current `VStack(spacing: 26)`).
- Copy is a short diary voice, exactly as written in this plan.
- After adding or removing any Swift file: `cd ios && xcodegen generate`. Never hand-edit `project.pbxproj`.
- JS style: `if (`, spaces around `=`, braces on the same line.
- Commits: a short imperative sentence. **No `Co-Authored-By` trailer** (user rule).
- iOS unit test command (referred to below as **UNIT**):
  `cd ios && xcodebuild test -project Marquee.xcodeproj -scheme Marquee -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:MarqueeTests/<Class> 2>&1 | grep -E "Test Case|error:|\*\* TEST" | tail -30`
- iOS build command (**BUILD**):
  `cd ios && xcodebuild -project Marquee.xcodeproj -scheme Marquee -destination 'generic/platform=iOS Simulator' build -quiet 2>&1 | grep -E "error:" ; echo done`

## Review Focus

1. **Double-tapping the mark button** must log exactly one episode. `UpNextModel` ignores a mark for a show whose id is already in `marking`. Test: `testSecondMarkWhileInFlightIsIgnored` (Task 4).
2. **Undo after the finished show's row was removed** must put the row back at its original index with its original record. Test: `testUndoRestoresRemovedRowAtIndex` (Task 4).
3. **"Today" across timezones and midnight.** Day labels and aired/unaired checks use an injected `today: Date` and `Calendar.current`. They never call `Date()` inside the logic. Tests: `testTrailingUnairedTomorrowShowsChip`, `testAgendaLabelsTonightTomorrowWeekday` (Task 2), and `dayKey` tests in the Node script (Task 8).
4. **A next episode with no air date, or a show with 0 total episodes,** must still get the mark button and hide the "x of y" caption. Tests: `testTrailingUnknownAirDateMarks`, `testProgressCaptionHiddenWhenTotalZero` (Task 2).
5. **An older server without `/api/home`** must fall back silently. Only a 404 triggers the fallback; 401 and 500 still surface. Test: `testFallbackOnlyOn404` (Task 10).

---

## File map

| File | Responsibility |
|---|---|
| `ios/Marquee/Core/EpisodeMarker.swift` (new) | Mark/undo the next episode. Shared by Home and `TVContinueView`. |
| `ios/Marquee/Features/Home/HomeFeed.swift` (new) | `HomeFeed` value types plus `HomeFeedLogic` pure functions |
| `ios/Marquee/Features/Home/HomeService.swift` (new) | Loads a `HomeFeed` (`/api/home`, else client aggregation) |
| `ios/Marquee/Features/Home/UpNextModel.swift` (new) | `@Observable` list state: mark, undo, toast |
| `ios/Marquee/Features/Home/HomeUpNext.swift` (new) | `UpNextSection`, `UpNextRow`, `UndoToast` views |
| `ios/Marquee/Features/Home/HomeSections.swift` (new; replaces `HomeLobbySections.swift`) | `AgendaSection`, `RecentlyLoggedSection`, `QueueSection`, `StarterSection`, `WeekPulseRow` (moved) |
| `ios/Marquee/Features/Home/HomeView.swift` (rewrite) | Composes the sections, owns load/refresh/cache |
| `ios/Marquee/Features/Home/HomeLobbyModels.swift` (delete) | Contents move or die (Task 7) |
| `ios/Marquee/Features/Home/WatchlistProviderFilter.swift` | Receives `StreamingFilterBar` and `StreamingProviderOption` |
| `ios/MarqueeTests/EpisodeMarkerTests.swift`, `HomeFeedLogicTests.swift`, `UpNextModelTests.swift`, `HomeServiceTests.swift` (new) | Unit tests |
| `backend-server/services/diaryActivity.js` (new) | `buildActivity(userId, limit)`, extracted from `routes/diary.js` |
| `backend-server/services/homeFeed.js` (new) | Pure schedule functions plus `buildHomeFeed(userId, { timeZone })` |
| `backend-server/routes/home.js` (new), `app.js` | `GET /api/home` |
| `backend-server/lib/tmdb.js` | `getTvSeason(tvId, season)` with a 6h TTL |
| `backend-server/scripts/test-home-feed.js` (new) | Assert tests for the pure functions |

---

## Phase A: client

### Task 1: EpisodeMarker (shared mark/undo)

**Files:**
- Create: `ios/Marquee/Core/EpisodeMarker.swift`
- Modify: `ios/Marquee/Features/TV/TVContinueView.swift` (`markNext()`, ~lines 216–260)
- Test: `ios/MarqueeTests/EpisodeMarkerTests.swift`

**Interfaces:**
- Produces:
  ```swift
  enum EpisodeMarker {
      struct Result: Sendable { let body: MarkEpisodeBody; let updated: TrackingRecord? }
      /// Pure: the pointer after `current`, given that season's episodes (sorted or not).
      static func following(after current: EpisodePointer, seasonEpisodes: [TVEpisode]?) -> EpisodePointer
      static func markNext(track: TrackingRecord, catalogTotal: Int?, runtime: Int?, episodeName: String?) async throws -> Result
      static func undo(_ body: MarkEpisodeBody) async throws
  }
  ```

- [ ] **Step 1: Write failing tests** in `EpisodeMarkerTests.swift`:
  - `testFollowingPicksNextEpisodeInSeason`: episodes 1,2,3 (season 1), current S1E2 → `EpisodePointer(season: 1, episode: 3, name: <ep3 name>)`.
  - `testFollowingSkipsGapsInNumbering`: episodes 1,2,5 (season 1), current S1E2 → S1E5.
  - `testFollowingRollsToNextSeasonAfterLast`: episodes 1,2, current S1E2 → `EpisodePointer(season: 2, episode: 1, name: nil)`.
  - `testFollowingWithNilEpisodesAssumesNextNumber`: `seasonEpisodes: nil`, current S3E4 → S3E5.
  Build `TVEpisode` values with the memberwise or decoding init used in `Core/TMDBModels.swift`. If it has no memberwise init, decode from a JSON string literal.
- [ ] **Step 2: Run UNIT with `EpisodeMarkerTests`.** Expected: build fails because `EpisodeMarker` is undefined.
- [ ] **Step 3: Implement `EpisodeMarker`.** `following` is the season-lookup logic now inline in `TVContinueView.markNext()`, plus the gap rule: pick the minimum `episode_number` greater than the current one. `markNext` does the following:
  1. Compute `ShowProgress.from(track:catalogTotal:).next`, and throw `APIError.empty` if it is nil.
  2. Fetch `TMDBService.season(tvId:season:)`, then call `following`.
  3. Build the `MarkEpisodeBody` exactly as `TVContinueView` does today: `totalEpisodes` and `airedEpisodeCount` = `catalogTotal ?? track.totalEpisodes ?? track.airedEpisodeCount`.
  4. Call `DiaryService.markEpisode`, then return `Result(body:updated: try? await DiaryService.tracking(for:))`.

  `undo` calls `DiaryService.unmarkEpisode(body)`.
- [ ] **Step 4: Make `TVContinueView.markNext()` guard `let track = tracking ?? seed` (else set `error = "No next episode."` and return), then call `EpisodeMarker.markNext(track: track, catalogTotal: catalog ?? catalogTotal, runtime: episode?.runtime, episodeName: episode?.name)`.** Keep its haptic, error and re-hydrate behaviour. Set `tracking = result.updated ?? tracking`.
- [ ] **Step 5: `xcodegen generate`, run UNIT with `EpisodeMarkerTests`.** Expected: 4 tests pass. Run BUILD: no errors.
- [ ] **Step 6: Commit** `Extract episode marking into EpisodeMarker.`

### Task 2: HomeFeed types and pure logic

**Files:**
- Create: `ios/Marquee/Features/Home/HomeFeed.swift`
- Test: `ios/MarqueeTests/HomeFeedLogicTests.swift`

**Interfaces:**
- Consumes: `TrackingRecord`, `WeekRecap`, `FavoriteMovieDoc`, `FavoriteTVDoc`, `DiaryActivityItem` (existing), `ShowProgress`.
- Produces:
  ```swift
  struct UpNextItem: Codable, Identifiable, Sendable { var id: String { track.tvId }; var track: TrackingRecord; var nextAirDate: String? }  // "YYYY-MM-DD"
  struct AgendaEpisode: Codable, Identifiable, Sendable {
      var id: String { "\(tvId)-\(season)-\(episode)" }
      let tvId: Int; let title: String; let posterPath: String?
      let season: Int; let episode: Int; let episodeName: String?
      let airDate: String; let kind: String   // "airing" | "returning"
  }
  struct HomeFeed: Codable, Sendable {
      var upNext: [UpNextItem]; var pausedCount: Int; var thisWeek: [AgendaEpisode]
      var recent: [DiaryActivityItem]; var recap: WeekRecap?
      var films: [FavoriteMovieDoc]; var tv: [FavoriteTVDoc]
      static let empty: HomeFeed
  }
  enum UpNextTrailing: Equatable { case mark, airs(String), chevron }
  struct AgendaRow: Identifiable, Equatable { let id: String; let dayLabel: String?; let episode: AgendaEpisode }
  enum HomeFeedLogic {
      static func trailing(for item: UpNextItem, today: Date, calendar: Calendar = .current) -> UpNextTrailing
      static func progressCaption(_ p: ShowProgress) -> String?
      static func dayLabel(_ airDate: String, today: Date, calendar: Calendar = .current) -> String
      static func agendaRows(_ eps: [AgendaEpisode], today: Date, calendar: Calendar = .current) -> [AgendaRow]
      static func recentCaption(_ item: DiaryActivityItem, today: Date, calendar: Calendar = .current) -> String
      static func headerSubtitle(_ feed: HomeFeed, today: Date, calendar: Calendar = .current) -> String
      static func isStarter(_ feed: HomeFeed) -> Bool
  }
  ```
  `DiaryActivityItem` must be `Codable` (it is `Decodable` today). Add `Encodable` conformance in `DiaryActivityView.swift`, plus a `CodingKeys` if needed, so `HomeFeed` can be cached.

- [ ] **Step 1: Write failing tests.** Use a fixed `today` = 2026-11-24 (a Tuesday) at noon, built with `Calendar(identifier: .gregorian)` set to `TimeZone(identifier: "America/New_York")`. Pass that calendar into every call.
  - `testTrailingRewatchingIsChevron`: status `"rewatching"` → `.chevron`.
  - `testTrailingUnknownAirDateMarks`: `nextAirDate: nil` → `.mark`.
  - `testTrailingAiredTodayMarks`: `"2026-11-24"` → `.mark`. And `"2026-11-20"` → `.mark`.
  - `testTrailingUnairedTomorrowShowsChip`: `"2026-11-25"` → `.airs("Tomorrow")`. `"2026-11-27"` → `.airs("Fri")`. `"2026-12-09"` → `.airs("Dec 9")`.
  - `testProgressCaptionHiddenWhenTotalZero`: total 0 → nil. `watched 5, total 10` → `"5 of 10"`.
  - `testAgendaLabelsTonightTomorrowWeekday`: `dayLabel` gives `"Tonight"` for today, `"Tomorrow"`, then `"Thu 26"` for 2026-11-26 (format `weekday(.abbreviated) + " " + day`).
  - `testAgendaRowsCapsAndFirstOfDay`: given 10 episodes, 3 of them on the same day: result count ≤ 8, sorted by `airDate`, only the first row of each day has a non-nil `dayLabel`, and episodes >7 days out with `kind == "airing"` are dropped. `"returning"` episodes up to 30 days out are kept.
  - `testRecentCaptionEpisodeAndFilm`: episode subtitle `"S1E4 · Name"` watched yesterday → `"S1E4 · Yesterday"`. Film with rating 4 → `"Film · ★4"`. Film without rating, watched 3 days ago → `"Film · Sat"`. Anything 7+ days ago → `"Nov 3"`-style. Today → `"Today"`.
  - `testHeaderSubtitlePriority`: an airing-today agenda item plus 3 upNext → `"3 shows waiting · Shōgun airs tonight"`. Only airing today → `"Shōgun airs tonight."`. 1 upNext → `"1 show waiting."`. Only thisWeek → `"New episodes this week."`. Only films → `"Your queue is waiting."`. Empty → `"Let's start your diary."`.
  - `testIsStarterOnlyWhenEverythingEmpty`: `HomeFeed.empty` → true. With `pausedCount 1` → false.
- [ ] **Step 2: Run UNIT with `HomeFeedLogicTests`.** Expected: fails because the types are undefined.
- [ ] **Step 3: Implement `HomeFeed.swift`.** Parse `"YYYY-MM-DD"` with `calendar.date(from: DateComponents(...))`, the same as `parseDay` in `HomeSchedule.swift`. Compare with `calendar.startOfDay`. For recent captions, take the first `" · "`-separated part of `subtitle` and drop the leading `"Rewatch · "`.
- [ ] **Step 4: `xcodegen generate`, then run UNIT with `HomeFeedLogicTests`.** Expected: all pass.
- [ ] **Step 5: Commit** `Add Home feed model and day logic.`

### Task 3: HomeService (client aggregation)

**Files:**
- Create: `ios/Marquee/Features/Home/HomeService.swift`
- Modify: `ios/Marquee/Core/DiaryService.swift` (add `activity(limit:)`), `ios/Marquee/Features/Diary/DiaryActivityView.swift` (use it), `ios/Marquee/Features/Home/HomeSchedule.swift` (window params)

**Interfaces:**
- Consumes: `HomeFeed`, `UpNextItem`, `AgendaEpisode` (Task 2). `HomeScheduleBuilder.upcoming(from:withinDays:)` and `.returningSoon(from:withinDays:)` (existing).
- Produces:
  ```swift
  extension DiaryService { static func activity(limit: Int) async throws -> [DiaryActivityItem] }  // GET /api/diary/activity?limit=
  enum HomeService {
      static let cacheKey = "home.landing.v2"
      static func load() async throws -> HomeFeed           // Phase A: = loadAggregated(); Task 10 adds /api/home
      static func loadAggregated() async throws -> HomeFeed
      static func cached() -> HomeFeed?
      static func store(_ feed: HomeFeed)
      static func clearCache()
  }
  ```
- [ ] **Step 1: Move the activity fetch into `DiaryService.activity(limit:)`.** Make `DiaryActivityResponse` file-internal to `DiaryService.swift`. `DiaryActivityView.load()` calls `DiaryService.activity(limit: 120)`.
- [ ] **Step 2: Implement `loadAggregated()`.**
  1. Run these in parallel with `async let`: `continueWatching()`, `library(tab: "stopped")`, `library(tab: "finished")`, `movieWatchlist()`, `tvWatchlist()`, `weekRecap()`, `activity(limit: 10)`. Continue and the watchlists throw. The others use `try?` with a default.
  2. Then `upcoming(from: cont + paused, withinDays: 7)` and `returningSoon(from: paused + finished, withinDays: 30)`, deduped by `tvId`+`airDate` the way `HomeView.load()` does today.
  3. Map `ScheduleEpisode` → `AgendaEpisode` with kind `"airing"`/`"returning"`.
  4. `upNext` = each continue track, with `nextAirDate` = the `airDate` of the schedule entry matching `tvId`/`nextSeason`/`nextEpisode`, else nil.
  5. `pausedCount = paused.count`.
- [ ] **Step 3: Implement `cached`/`store`/`clearCache`** via `ResponseCache` with `cacheKey`. Check how `ResponseCache` removes an entry, and add `remove(key:)` if it has none.
- [ ] **Step 4: Run BUILD.** Expected: no errors. HomeView doesn't use `HomeService` until Task 6, so the build is the check here.
- [ ] **Step 5: Commit** `Load Home from one HomeService feed.`

### Task 4: UpNextModel (mark, undo, toast state)

**Files:**
- Create: `ios/Marquee/Features/Home/UpNextModel.swift`
- Test: `ios/MarqueeTests/UpNextModelTests.swift`

**Interfaces:**
- Consumes: `UpNextItem`, `EpisodeMarker.Result`.
- Produces:
  ```swift
  @MainActor @Observable final class UpNextModel {
      struct Toast: Equatable { let title: String; let body: MarkEpisodeBody? ; let id: UUID }  // title e.g. "Logged Silo S1E6"
      private(set) var items: [UpNextItem]
      private(set) var marking: Set<String> = []
      private(set) var justMarked: Set<String> = []   // drives the 0.6s check morph
      var toast: Toast?
      var errorMessage: String?
      init(items: [UpNextItem],
           mark: @escaping (TrackingRecord) async throws -> EpisodeMarker.Result,
           undo: @escaping (MarkEpisodeBody) async throws -> Void,
           onChange: @escaping () -> Void = {})
      func replace(_ items: [UpNextItem])
      func mark(_ item: UpNextItem) async
      func undoLast() async
  }
  ```
  `MarkEpisodeBody` must become `Equatable` (add the conformance in `DiaryModels.swift`). Keep the last undo snapshot privately as `(index: Int, item: UpNextItem, body: MarkEpisodeBody)`.

- [ ] **Step 1: Write failing tests** with stub closures. Use a `CheckedContinuation`-gated stub for the in-flight test.
  - `testMarkUpdatesRowInPlace`: stub returns `updated` with `nextEpisode` 6. `items[0].track.nextEpisode == 6`. `toast?.title == "Logged Silo S1E5"`. `onChange` was called once.
  - `testMarkRemovesFinishedShow`: stub returns `updated.status == "completed"` → the row is removed.
  - `testMarkAdvancesLocallyWhenUpdatedNil`: `updated == nil` → the row stays, with `nextEpisode` advanced locally to `body.nextSeason/nextEpisode`.
  - `testSecondMarkWhileInFlightIsIgnored`: call `mark` twice concurrently for the same item → the stub's call count is 1.
  - `testMarkFailureRevertsAndSetsError`: stub throws → items unchanged, `errorMessage == "Couldn't log that. Try again."`, `marking` is empty.
  - `testUndoRestoresRemovedRowAtIndex`: 3 items. Mark the middle one (finished → removed). `undoLast()` → the original record is back at index 1, `toast == nil`, and the undo stub got the same body.
  - `testNewMarkReplacesUndoTarget`: mark A, then mark B, then `undoLast()` → only B's body goes to the undo stub.
- [ ] **Step 2: Run UNIT with `UpNextModelTests`.** Expected: fails because `UpNextModel` is undefined.
- [ ] **Step 3: Implement.** In `mark`:
  1. Return if `marking` contains the id. Otherwise insert the id and remember the index and item.
  2. `await mark(track)`.
  3. On success: if `updated?.status == "completed"` remove the row, else replace the track with `updated` (or the locally advanced copy). Insert the id into `justMarked` and remove it after `Task.sleep(for: .milliseconds(600))`. Set the toast and call `onChange()`.
  4. Always remove the id from `marking`.

  Format the toast title as `"Logged \(title) S\(s)E\(e)"` using the marked body.
- [ ] **Step 4: Run UNIT with `UpNextModelTests`.** Expected: 7 pass.
- [ ] **Step 5: Commit** `Add Up next model with one-tap mark and undo.`

### Task 5: Up next views and toast

**Files:**
- Create: `ios/Marquee/Features/Home/HomeUpNext.swift`

**Interfaces:**
- Consumes: `UpNextModel` (Task 4), `HomeFeedLogic.trailing/progressCaption` (Task 2), `TVContinueView`, `TVDetailView`, `TVLibraryView(initialTab:)`, `MediaBrowseView(kind:)`, `ProgressTrack`, `SkeletonBlock`.
- Produces:
  ```swift
  struct UpNextSection: View { let model: UpNextModel; let pausedCount: Int; let loading: Bool; let today: Date }
  struct UndoToast: View { let toast: UpNextModel.Toast; let onUndo: () -> Void }
  ```
- [ ] **Step 1: Build `UpNextSection`.**
  - **Header:** `Text("Up next")` (`.title3.weight(.semibold)`, ink). When `model.items.count > 6`, a trailing `NavigationLink("All \(count)")` to `TVLibraryView(initialTab: .watching)` (caption semibold, olive). Add `.accessibilityIdentifier("home-upnext")` on the section container.
  - **Rows:** `ForEach(model.items.prefix(6))` → `UpNextRow`, separated by `Divider().overlay(theme.border)` with a leading inset of 76.
  - **Row container:** `surfaceElevated` background, corner 18, 1pt `theme.border` stroke. No glass.
  - **Paused row:** when `pausedCount > 0`, a row below the container with `Text("Paused · \(pausedCount)")` (subheadline semibold, ink) and a chevron in olive. It's a `NavigationLink` to `TVLibraryView(initialTab: .stopped)`.
  - **Loading** (`loading && items.isEmpty`): three `SkeletonBlock(height: 90, radius: 14)`.
  - **Empty** (`!loading && items.isEmpty`): a card reading `"Nothing in progress."` / `"Start a show from TV."`, with an olive `TV` button linking to `MediaBrowseView(kind: .tv)`.
- [ ] **Step 2: Build `UpNextRow`** (private) with `HStack(spacing: 12)`:
  - **Poster:** `CachedAsyncImage` at 60×90, corner 10.
  - **Text column:** title (`.headline`, `lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)`). Then `"S\(s) · E\(e)"` plus `"  " + name` (`.subheadline`, inkMuted, 1 line). Then `ProgressTrack` (max width 140) with the caption from `progressCaption` (`.caption2.weight(.semibold)`, olive, `monospacedDigit`), hidden when the caption is nil.
  - **Trailing control** (switch on `HomeFeedLogic.trailing(for:today:)`):
    - `.mark` is a `Button` in a 44×44 `Circle().fill(theme.accent)` containing `Image(systemName: justMarked ? "checkmark.circle.fill" : "checkmark")`, white, `.body.weight(.bold)`. Show a white `ProgressView()` while `marking`. Disable it while marking. Add `.accessibilityLabel("Mark \(title) season \(s) episode \(e) watched")`. On tap it calls `Haptics.light()`, then `Task { await model.mark(item) }`. On `justMarked`, apply `.scaleEffect(1.12)` with `MarqueeMotion.micro`, skipped under Reduce Motion.
    - `.airs(label)` is a `Text(label)` with caption bold, olive, on a `theme.oliveSoft` capsule.
    - `.chevron` is the `chevron.right` symbol in olive.
  - **Row tap:** the whole row except the button is a `NavigationLink`. It goes to `TVContinueView(tvId:seed:catalogTotal:nil)`, or to `TVDetailView(tvId:)` when `.chevron`. Use `.buttonStyle(.plain)`. The mark button sits outside the link label, as a sibling in the `HStack`, so the two taps don't conflict.
  - **Accessibility:** add `.accessibilityAction(named: "Mark watched")` on the row when trailing is `.mark`.
  - **Row removal:** `.transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .leading)))`. Animate list changes with `.animation(reduceMotion ? nil : MarqueeMotion.standard, value: model.items.map(\.id))`.
- [ ] **Step 3: Build `UndoToast`.**
  - It's an `HStack` holding `Text(toast.title)` (subheadline semibold, ink, 1 line) and `Button("Undo")` (subheadline bold, `theme.accentInk`).
  - Padding is 14 horizontal and 10 vertical, with `.glassEffect(.regular, in: Capsule())`.
  - Add `.accessibilityElement(children: .combine)` and `.accessibilityAction(named: "Undo")`.
- [ ] **Step 4: Run BUILD.** Expected: no errors. (Visual check happens in Task 6.)
- [ ] **Step 5: Commit** `Add Up next list with one-tap mark button and undo toast.`

### Task 6: Other sections and the HomeView rewrite

**Files:**
- Create: `ios/Marquee/Features/Home/HomeSections.swift`
- Rewrite: `ios/Marquee/Features/Home/HomeView.swift`
- Modify: `ios/Marquee/Core/UITestingFixtures.swift`, `ios/MarqueeUITests/MarqueeVisualUITests.swift`

**Interfaces:**
- Consumes: everything from Tasks 2–5, plus `WeekPulseRow`, `PosterTile`, `MediaNavLink`, `WatchlistView(initialScope:)`, `DiaryActivityView`, `TMDBService.fetchPaged`.
- Produces:
  ```swift
  struct AgendaSection: View { let rows: [AgendaRow] }
  struct RecentlyLoggedSection: View { let items: [DiaryActivityItem]; let today: Date }
  struct QueueSection: View { let films: [FavoriteMovieDoc]; let tv: [FavoriteTVDoc] }
  struct StarterSection: View { }   // loads trending itself
  ```
- [ ] **Step 1: Build `HomeSections.swift`.**
  - **Move `WeekPulseRow` here** unchanged from `HomeLobbySections.swift`.
  - **`AgendaSection`:**
    - Header `"This week"`. Hidden when `rows` is empty.
    - Each row is an `HStack(alignment: .firstTextBaseline)`: a day label column (width 64; `.caption.weight(.bold)`, uppercase, tracked, olive; empty when `dayLabel` is nil), the title (`.subheadline.weight(.semibold)`, ink), and the detail on a second line (`.caption`, inkMuted). The detail is `"S\(s)E\(e) · \(name)"` for airing, or `"Season \(s) returns"` for returning.
    - Rows sit in a `surfaceElevated` container (corner 18, border stroke) with dividers between them. There are no posters.
    - Each row is a `NavigationLink` to `TVDetailView(tvId:)`.
  - **`RecentlyLoggedSection`:**
    - Header `"Recently logged"`, with a trailing `NavigationLink("Calendar")` to `DiaryActivityView()` carrying `.accessibilityIdentifier("watch-calendar-link")`.
    - A horizontal `LazyHStack(spacing: 12)` of `PosterTile(title:posterPath:width: 96, year: HomeFeedLogic.recentCaption(item, today:))`. Check that `year` renders as the caption line in `PosterTile`; if it doesn't, add a `caption` parameter.
    - Tap goes to `TVDetailView(tvId: Int(mediaId))` for kind `"episode"`, and `MediaNavLink(id:kind: .movie)` for `"film"`.
    - Hidden when empty.
  - **`QueueSection`:**
    - Header `"Your queue"` with a `Picker` (`.segmented`, width 150) between `Films` and `TV`. Show the picker only when both lists are non-empty. The `@State` default is `.films` when films is non-empty, else `.tv`.
    - The trailing `NavigationLink("All")` goes to `WatchlistView(initialScope: .films/.tv)`.
    - The rail holds up to 12 `PosterTile`s via `MediaNavLink`, like today's `lobbyWatchlistRail`.
    - Hidden when both lists are empty.
  - **`StarterSection`:**
    - Title `"Start your diary"` (`.title2.bold`). Body `"Track a show and your next episode lands here, ready to log."`
    - Two shortcut buttons, `Find a show` → `MediaBrowseView(kind: .tv)` and `Find a film` → `MediaBrowseView(kind: .movie)`, in the style of today's `LobbyEmptyState.shortcut`.
    - Then a `"Trending this week"` rail. Its `.task` loads `TMDBService.fetchPaged("trending/tv/week").results.prefix(12)`, shows a `RailSkeleton()` while loading, and hides the rail on error.
- [ ] **Step 2: Rewrite `HomeView`.**
  - **State:** `feed: HomeFeed`, `loading`, `error`, and `upNext: UpNextModel`, created in `init` with `mark: { try await EpisodeMarker.markNext(track: $0, catalogTotal: nil, runtime: nil, episodeName: nil) }`, `undo: EpisodeMarker.undo`, and `onChange: { Task { await refreshAfterMark() } }`.
  - **Body order:**
    - header (greeting unchanged; subtitle from `HomeFeedLogic.headerSubtitle(feed, today: .now)`)
    - then either `StarterSection()` (when `!loading && HomeFeedLogic.isStarter(feed)`), or: `UpNextSection` → `AgendaSection(rows: HomeFeedLogic.agendaRows(feed.thisWeek, today: .now))` → `RecentlyLoggedSection` → `WeekPulseRow` (if recap) → `QueueSection`
    - then the error views as today.
  - **Overlay:** `.overlay(alignment: .bottom)` shows the `UndoToast` when `upNext.toast != nil`, padded 12 above the bottom safe area. Auto-dismiss it with `.task(id: toast.id) { try? await Task.sleep(for: .seconds(5)); upNext.toast = nil }`. Use the transition `.move(edge: .bottom).combined(with: .opacity)`, or `.opacity` under Reduce Motion.
  - **Inline error:** when `upNext.errorMessage` is set, show an `InlineErrorBanner` with that message, whose retry clears the message.
  - **`load()`:**
    1. If `feed` is empty, read `HomeService.cached()` and apply it.
    2. `feed = try await HomeService.load()`, then `upNext.replace(feed.upNext)`, then `HomeService.store(feed)`.
    3. Keep `WidgetSnapshotStore.save(...)` with the same fields, using `feed.upNext.first?.track` and `feed.recap`.
    4. Call `EpisodeAlertScheduler.refresh`, mapping `feed.thisWeek` where `kind == "airing"` back to `ScheduleEpisode`.
    5. Keep the error messages from today's `load()`.
  - **`refreshAfterMark()`:** `HomeService.clearCache()`, then refetch only `DiaryService.weekRecap()` and `DiaryService.activity(limit: 10)` into `feed`. Do not touch `upNext`.
  - **Keep** `.marqueeCanvas()`, `.marqueeLandingChrome()`, `.refreshable`, and the `UITestingFixtures` branch, which now sets `feed.upNext = UITestingFixtures.continueItems.map { UpNextItem(track: $0, nextAirDate: nil) }`.
- [ ] **Step 3: Update `MarqueeVisualUITests.testCaptureHomeAndCalendar`.**
  - Wait for `app.otherElements["home-upnext"]`, or `app.descendants(matching: .any)["home-upnext"]`.
  - Remove the carousel swipe block.
  - Keep the calendar part, but tap `app.buttons["watch-calendar-link"]`, scrolling up until it exists, at most 4 swipes.
- [ ] **Step 4: Verify.**
  - Run `xcodegen generate` and then BUILD: no errors.
  - Run UNIT for the whole `MarqueeTests` target: all pass.
  - Run `ios/scripts/shots.sh` with `SCREENS=home`, then again with `SCREENS=home APPEARANCE=dark`. Read `/tmp/marquee-shots/s-home.png` after each run, because the second run overwrites the first.
  - Check that both shots show the header, the Up next rows each with a pink check button, and no blurred hero. If the simulator is signed out, sign in once in the simulator, then re-run.
  - Run `xcodebuild test ... -only-testing:MarqueeUITests/MarqueeVisualUITests`: passes.
- [ ] **Step 5: Commit** `Rebuild Home around Up next, This week and Recently logged.`

### Task 7: Remove dead Home code

**Files:**
- Delete: `ios/Marquee/Features/Home/HomeLobbySections.swift`, `ios/Marquee/Features/Home/HomeLobbyModels.swift`
- Modify: `ios/Marquee/Features/Home/WatchlistProviderFilter.swift`

- [ ] **Step 1: Move `StreamingFilterBar` and `StreamingProviderOption` verbatim into `WatchlistProviderFilter.swift`.** They're used by Watchlist, Browse, Settings and CatalogShelves.
- [ ] **Step 2: Delete the two files.** That removes `TonightCard`, `TonightPicker`, `TonightPick`, `TonightKind`, `HomeRecommendation`, `ForYouRail`, `HomeShowRail`, `HomeScheduleRail`, `UpNextStrip`, `LobbyTimelineRail`, `ThisWeekCardChrome`, `LobbyEmptyState`, `ThisWeekBuilder` and `ThisWeekItem`.
- [ ] **Step 3: Remove `ContinueHeroCard` and `ContinueCard`** from the old `HomeView.swift`. They should already be gone after the rewrite.
- [ ] **Step 4: Check that no references remain.**
  - Run: `grep -rnE "TonightCard|TonightPicker|ForYouRail|HomeShowRail|HomeScheduleRail|UpNextStrip|LobbyTimelineRail|ContinueHeroCard|ContinueCard\(|ThisWeekBuilder|LobbyEmptyState|HomeRecommendation" ios/Marquee ios/MarqueeTests ios/MarqueeUITests ios/MarqueeWidgets`
  - Expected: no output. If something outside Home uses a symbol, keep that symbol and move it next to its user.
- [ ] **Step 5: Run `xcodegen generate`, then BUILD and UNIT (all `MarqueeTests`).** Expected: clean.
- [ ] **Step 6: Commit** `Remove unused Home rails and cards.`

---

## Phase C: `GET /api/home`

### Task 8: Backend pure schedule logic and shared activity builder

**Files:**
- Create: `backend-server/services/diaryActivity.js`, `backend-server/services/homeFeed.js`, `backend-server/scripts/test-home-feed.js`
- Modify: `backend-server/routes/diary.js`, `backend-server/package.json` (script `"test:home": "node scripts/test-home-feed.js"`)

**Interfaces:**
- Produces:
  ```js
  // services/diaryActivity.js
  async function buildActivity(userId, limit) -> Array<{ kind, id, mediaId, title, posterPath, subtitle, isRewatch, watchedAt, rating }>
  // services/homeFeed.js (pure, exported for tests)
  function dayKey(date, timeZone) -> 'YYYY-MM-DD'          // via Intl.DateTimeFormat('en-CA', { timeZone })
  function addDays(dayKeyStr, n) -> 'YYYY-MM-DD'
  function upcomingFromSeason(track, seasonJson, todayKey, windowDays) -> Array<AgendaEpisode>   // kind 'airing'
  function firstReturnFromSeason(track, seasonJson, todayKey, windowDays) -> AgendaEpisode|null   // kind 'returning'
  function nextAirDateFor(track, agenda) -> 'YYYY-MM-DD'|null
  function mergeAgenda(airing, returning) -> Array<AgendaEpisode>   // dedupe tvId+airDate, returning dropped if tvId already airing, sorted by airDate
  ```
  `AgendaEpisode` JSON uses the same keys as the Swift struct: `tvId` (number), `title`, `posterPath`, `season`, `episode`, `episodeName`, `airDate`, `kind`.

- [ ] **Step 1: Extract the body of `GET /activity` into `buildActivity`.** The route becomes `res.json({ success: true, items: await buildActivity(req.user._id, limit) })`. Behaviour is unchanged.
- [ ] **Step 2: Write failing tests** in `test-home-feed.js`, using the `test(name, fn)` helper style from `test-tv-rewatch.js`:
  - `dayKey`: `new Date('2026-11-25T03:30:00Z')` in `America/New_York` → `'2026-11-24'`, and in `UTC` → `'2026-11-25'`.
  - `addDays('2026-11-28', 3)` → `'2026-12-01'`.
  - `upcomingFromSeason` with today `'2026-11-24'` and window 7: episodes on 11-23 (past), 11-24, 11-30 and 12-02 → returns 11-24 and 11-30 only, kind `'airing'`, `title` and `posterPath` taken from the track (`tvTitle`, `tvPosterImage || tvPost`).
  - `firstReturnFromSeason`: first dated episode on 12-20 with window 30 → returned. On 12-30 → null.
  - `nextAirDateFor`: a track with `nextSeason 1`, `nextEpisode 8` against an agenda containing S1E8 on 11-24 → `'2026-11-24'`. With no match → null.
  - `mergeAgenda`: a returning entry for a tvId already in airing is dropped; the output is sorted by airDate.
- [ ] **Step 3: Run `node backend-server/scripts/test-home-feed.js`.** Expected: fails with `Cannot find module '../services/homeFeed'`.
- [ ] **Step 4: Implement the pure functions** in `services/homeFeed.js`. Do the date math on `'YYYY-MM-DD'` strings via `Date.UTC`, which is timezone-free. Use `track.tvId` as a `Number`.
- [ ] **Step 5: Run the tests again, plus `node backend-server/scripts/test-tv-rewatch.js`.** Expected: all `ok —` lines and no FAIL.
- [ ] **Step 6: Commit** `Add Home feed schedule helpers and share the diary activity builder.`

### Task 9: `getTvSeason` with TTL and the `/api/home` route

**Files:**
- Modify: `backend-server/lib/tmdb.js`, `backend-server/services/homeFeed.js`, `backend-server/app.js`
- Create: `backend-server/routes/home.js`

**Interfaces:**
- Consumes: Task 8 functions, `buildWeekRecap(userId, { timeZone })`, `resolveTimeZone` (from `services/statsCalendar`), and the models `TvShowTracking`, `MovieWatchlist` and `TvWatchlist` (use the same models and queries as the existing `routes/moviewatchlist.js` and `routes/tvwatchlist.js` GET handlers; read them first).
- Produces:
  ```js
  // lib/tmdb.js
  async function getTvSeason(tvId, season) -> seasonJson|null   // 6h TTL Map keyed `tv/${tvId}/season/${season}`, fetched via tmdbRequest-style rate limit but NOT the permanent memoryCache
  // services/homeFeed.js
  async function buildHomeFeed(userId, { timeZone }) -> { upNext, pausedCount, thisWeek, recent, recap, watchlist: { films, tv } }
  ```
- [ ] **Step 1: Add `getTvSeason`.**
  - Factor the fetch part of `tmdbRequest` into `fetchTmdb(endpoint)`, which handles rate limiting but no caching. `tmdbRequest` keeps its permanent memo by calling it.
  - `getTvSeason` keeps a `Map` of `{ data, at }` and refetches when the entry is older than `6 * 60 * 60 * 1000` ms. Cap the map at 500 entries by deleting the oldest key on insert.
  - Export it.
- [ ] **Step 2: Implement `buildHomeFeed`.**
  1. Compute `todayKey = dayKey(new Date(), timeZone)`.
  2. Fetch continue tracks with the same query as `GET /api/tv/tracking/continue`: run `autoPauseStaleTracks` first, then status `watching`/`rewatching`, `watchedEpisodeCount > 0`, sorted by `lastWatchedAt`, limit 24. `autoPauseStaleTracks` lives in `routes/tvtracking.js`; if it isn't exported from a service, move it to `services/tvTrackingMaintenance.js` and import it in both places.
  3. Fetch paused tracks (status `paused`) and finished tracks (status `completed`), using the same filters as `library/:tab` for `stopped`/`finished`. Read that handler first.
  4. Airing: for the first 16 of continue + paused, `getTvSeason(tvId, nextSeason || 1)`, then `upcomingFromSeason(..., 7)`.
  5. Returning: for the first 12 of paused + finished, try season `lastSeason + 1`, then `+2`, through `firstReturnFromSeason(..., 30)`.
  6. Run the season fetches with `Promise.all`.
  7. Return `thisWeek = mergeAgenda(...)`, `upNext = continue.map(t => ({ track: t, nextAirDate: nextAirDateFor(t, thisWeek) }))`, `recent = buildActivity(userId, 10)`, `recap = buildWeekRecap(...)`, and `watchlist`.
- [ ] **Step 3: Create `routes/home.js`.** It's `router.get('/', authenticate.verifyUser, ...)`, which takes `timeZone` from `resolveTimeZone(req.query.tz || req.headers['x-timezone'])` and responds `{ success: true, ...feed }`. Mount it in `app.js` after the diary route: `app.use('/api/home', require('./routes/home'));`.
- [ ] **Step 4: Verify against a local server.**
  1. Start `cd backend-server && npm run start:api` in the background.
  2. Get a JWT from the simulator's Keychain or by signing in via `POST /users/login`. Ask the user for test credentials if needed; never hard-code them.
  3. Run `curl -s -H "Authorization: Bearer $TOKEN" -H "X-Timezone: America/New_York" localhost:5001/api/home | node -e "const j=JSON.parse(require('fs').readFileSync(0));console.log(j.success, j.upNext.length, j.thisWeek.length, j.recent.length, !!j.recap)"`
  4. Expected: `true` followed by numbers, with no stack trace in the server log.
  5. Also run `node backend-server/scripts/test-home-feed.js`, which should still pass.
- [ ] **Step 5: Commit** `Serve the Home feed from GET /api/home.`

### Task 10: Client uses `/api/home` with fallback

**Files:**
- Modify: `ios/Marquee/Features/Home/HomeService.swift`
- Test: `ios/MarqueeTests/HomeServiceTests.swift`

**Interfaces:**
- Consumes: `HomeFeed` (Task 2) and the JSON shape from Task 9.
- Produces:
  ```swift
  struct HomeAPIResponse: Decodable, Sendable {
      let success: Bool?; let upNext: [UpNextItem]?; let pausedCount: Int?; let thisWeek: [AgendaEpisode]?
      let recent: [DiaryActivityItem]?; let recap: WeekRecap?; let watchlist: Watchlist?
      struct Watchlist: Decodable, Sendable { let films: [FavoriteMovieDoc]?; let tv: [FavoriteTVDoc]? }
      var feed: HomeFeed { get }
  }
  extension HomeService {
      static func shouldFallback(_ error: Error) -> Bool
      static func loadFromServer() async throws -> HomeFeed   // GET /api/home
  }
  ```
- [ ] **Step 1: Write failing tests.**
  - `testDecodesHomeResponse` decodes a JSON literal with one upNext entry (`{"track":{"tvId":"1","status":"watching","nextSeason":1,"nextEpisode":2},"nextAirDate":"2026-11-24"}`), one thisWeek entry, `recent: []`, `recap: {"streak":2}`, and `watchlist: {"films":[],"tv":[]}`. Assert `feed.upNext[0].nextAirDate == "2026-11-24"`, `feed.recap?.streak == 2`, and `feed.pausedCount == 0` when it's missing.
  - `testFallbackOnlyOn404`: `.server(message:"x", status:404)` → true. Status 500 → false. `.unauthorized` → false. `.transport(URLError(.notConnectedToInternet))` → false.
- [ ] **Step 2: Run UNIT with `HomeServiceTests`.** Expected: fails because the types are undefined.
- [ ] **Step 3: Implement.** `load()` becomes `do { return try await loadFromServer() } catch where shouldFallback(error) { return try await loadAggregated() }`. Map missing arrays to `[]` and a missing `pausedCount` to 0.
- [ ] **Step 4: Run UNIT for all of `MarqueeTests`.** Expected: pass. Run `API=http://localhost:5001 SCREENS=home ios/scripts/shots.sh` with the Task 9 server running, then read the screenshot. Home should render the same as in Task 6.
- [ ] **Step 5: Commit** `Load Home from /api/home, falling back on older servers.`

### Task 11: Final check on device

- [ ] **Step 1:** Run `node backend-server/scripts/test-home-feed.js`, then `node backend-server/scripts/test-stats-calendar.js`, `node backend-server/scripts/test-tv-rewatch.js` and `node backend-server/scripts/test-film-watch-plays.js`. All should pass.
- [ ] **Step 2:** Run UNIT for all of `MarqueeTests` and the UI test `MarqueeVisualUITests`. All should pass.
- [ ] **Step 3:** Take light and dark `shots.sh` screenshots. Check them against the spec's sketch and `ios/DESIGN.md`: the only pink is the mark buttons, progress and streak; there's no stat panel in the first viewport; the 20pt gutter holds.
- [ ] **Step 4:** Install on the iPhone. Follow the memory note `iphone-wireless-install`: build with `-destination 'generic/platform=iOS' -allowProvisioningUpdates`, then run `devicectl device install app` and `launch com.jimil.marquee`. Note that the phone talks to the deployed API, which only gets `/api/home` after a Render deploy. Until then, the fallback path is what runs, and that is expected.
- [ ] **Step 5:** Ask the user before pushing or deploying.
