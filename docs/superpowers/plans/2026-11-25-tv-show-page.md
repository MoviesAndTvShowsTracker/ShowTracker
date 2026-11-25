# TV Show Page Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild the TV show page around one action per state, a native Episodes | About switch, a calm episode list where only the circle marks, and a Start button that lands on S1 · E1.

**Architecture:** The state, copy and score decisions go into a pure `TVShowPageLogic` enum (unit-tested). The SwiftUI changes are split across `TVDetailHeader.swift` (new: header block), `TVDetailEpisodes.swift` (season row and rows), `TVDetailPane.swift` (segmented switch) and `TVDetailView.swift` (wiring, About order, scroll and highlight state). `MediaDetailShell` gains an optional scroll request. Films are untouched.

**Tech Stack:** SwiftUI (iOS 26), `@Observable`, XCTest, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-11-25-tv-show-page-design.md`

## Global Constraints

- Hibiscus (`theme.accent`) only for the one primary action, mark circle and progress. No second accent, no pink section labels.
- No glass on rows. Springs 100–250 ms (`MarqueeMotion.micro` / `.standard`). Every animation is nil under Reduce Motion.
- SF Pro only. Short diary copy.
- New Swift files → `cd ios && xcodegen generate`. Never hand-edit `project.pbxproj`.
- Film detail page, `RatingsStrip`, `DiaryGlassStrip` keep current behavior for films.
- Don't commit unless the user asks (user preference); stage nothing in between.

## Review Focus

1. **Show that hasn't premiered** (first_air_date in the future): no Start button, shows "Premieres Dec 3". Tested in Task 1 (`testPremiereStateForFutureShow`).
2. **Show with season 0 "Specials" first**: Start must target season 1, not specials. Tested in Task 1 (`testStartSkipsSpecials`).
3. **Untracked user taps Start while Episodes for another season is loaded**: season switches to the start season, the list loads, *then* scrolls. Covered by the Task 4 ordering (await `loadSeason()` before setting the scroll target) and the Task 7 manual check.
4. **Rewatching show**: row tap must keep today's circle behavior, not open the log sheet. Task 5 step and Task 7 check.
5. **One-season show**: no season menu, and no "Mark whole show" in ⋯ (it equals Mark season). Tested in Task 1 (`testWholeShowOnlyForMultiSeason`).

---

### Task 1: Page logic

**Files:**
- Create: `ios/Marquee/Features/TV/TVShowPageLogic.swift`
- Test: `ios/MarqueeTests/TVShowPageLogicTests.swift`

**Interfaces:**
- Produces:
  - `enum TVHeaderState: Equatable { case notStarted(season: Int), premieres(label: String), watching, rewatching, paused, finished(rated: Bool) }`
  - `TVShowPageLogic.headerState(status: String?, showRating: Double, seasons: [Int], firstAirDate: String?, showStatus: String?, today: Date, calendar: Calendar = .current) -> TVHeaderState`
  - `TVShowPageLogic.startSeason(_ seasons: [Int]) -> Int` (first season number > 0, else 1)
  - `TVShowPageLogic.heroScore(_ ratings: MediaRatings?) -> String?`
  - `TVShowPageLogic.seasonCountLine(watched: Int, aired: Int, total: Int) -> String`
  - `TVShowPageLogic.offersWholeShow(seasonCount: Int, canMarkWholeShow: Bool) -> Bool`

- [ ] **Step 1: Write the failing tests**

```swift
import XCTest
@testable import Marquee

final class TVShowPageLogicTests: XCTestCase {
    let cal: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    var today: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 25))! }

    func state(_ status: String?, rating: Double = 0, first: String? = "2024-01-01", showStatus: String? = "Returning Series") -> TVHeaderState {
        TVShowPageLogic.headerState(status: status, showRating: rating, seasons: [1, 2], firstAirDate: first, showStatus: showStatus, today: today, calendar: cal)
    }

    func testNotStartedTargetsFirstSeason() { XCTAssertEqual(state(nil), .notStarted(season: 1)) }
    func testDroppedIsNotStartedTreatedAsPaused() { XCTAssertEqual(state("dropped"), .paused) }
    func testStatesMap() {
        XCTAssertEqual(state("watching"), .watching)
        XCTAssertEqual(state("rewatching"), .rewatching)
        XCTAssertEqual(state("paused"), .paused)
        XCTAssertEqual(state("completed"), .finished(rated: false))
        XCTAssertEqual(state("completed", rating: 4), .finished(rated: true))
    }
    func testPremiereStateForFutureShow() { XCTAssertEqual(state(nil, first: "2026-12-03"), .premieres(label: "Premieres Dec 3")) }
    func testPremiereTodayCountsAsAired() { XCTAssertEqual(state(nil, first: "2026-11-25"), .notStarted(season: 1)) }
    func testPlannedWithoutDate() { XCTAssertEqual(state(nil, first: nil, showStatus: "Planned"), .premieres(label: "Not aired yet")) }
    func testStartSkipsSpecials() { XCTAssertEqual(TVShowPageLogic.startSeason([0, 1, 2]), 1) }
    func testStartFallsBackToOne() { XCTAssertEqual(TVShowPageLogic.startSeason([]), 1) }

    func testCountLine() {
        XCTAssertEqual(TVShowPageLogic.seasonCountLine(watched: 3, aired: 8, total: 8), "3 of 8 watched")
        XCTAssertEqual(TVShowPageLogic.seasonCountLine(watched: 0, aired: 6, total: 8), "0 of 6 watched · 2 to air")
    }
    func testWholeShowOnlyForMultiSeason() {
        XCTAssertFalse(TVShowPageLogic.offersWholeShow(seasonCount: 1, canMarkWholeShow: true))
        XCTAssertTrue(TVShowPageLogic.offersWholeShow(seasonCount: 2, canMarkWholeShow: true))
        XCTAssertFalse(TVShowPageLogic.offersWholeShow(seasonCount: 3, canMarkWholeShow: false))
    }
    func testHeroScorePrefersIMDbThenTMDB() throws {
        let both = try JSONDecoder().decode(MediaRatings.self, from: Data(#"{"id":1,"imdb":{"value":7.8,"scale":10},"tmdb":{"value":4.5,"scale":10}}"#.utf8))
        XCTAssertEqual(TVShowPageLogic.heroScore(both), "★ 7.8 IMDb")
        let tmdb = try JSONDecoder().decode(MediaRatings.self, from: Data(#"{"id":1,"tmdb":{"value":4.5,"scale":10}}"#.utf8))
        XCTAssertEqual(TVShowPageLogic.heroScore(tmdb), "★ 4.5 TMDB")
        XCTAssertNil(TVShowPageLogic.heroScore(nil))
    }
}
```

(If `ExternalScore`'s JSON keys differ from `value`/`scale`, match `RatingsChipTests.swift`'s fixtures.)

- [ ] **Step 2: Run, expect a compile failure (`TVShowPageLogic` not found)**

Run: `cd ios && xcodegen generate && xcodebuild test -project Marquee.xcodeproj -scheme Marquee -destination 'platform=iOS Simulator,id=043E452A-4D81-4962-82ED-4EE33267FA40' -only-testing:MarqueeTests/TVShowPageLogicTests 2>&1 | tail -5`

- [ ] **Step 3: Implement `TVShowPageLogic`**

Rules: status `nil` → premiere check, then `.notStarted(season: startSeason(seasons))`. Premiere: `firstAirDate` parsed as a day later than `today` → `"Premieres " + "MMM d"` (en_US_POSIX); nil date with `showStatus` in `["Planned", "In Production"]` → `"Not aired yet"`. `"dropped"` → `.paused`. `"completed"` → `.finished(rated: showRating > 0)`. Unknown non-nil status → `.watching`. `heroScore` takes the first of `ratings.chips` whose source is `.imdb` or `.tmdb` → `"★ \(display) \(source.label)"`. The `· N to air` suffix appears only when `total > aired`.

- [ ] **Step 4: Run, expect PASS** (same command)

---

### Task 2: Shell scroll request

**Files:**
- Modify: `ios/Marquee/DesignSystem/MediaDetailShell.swift` (`MediaDetailShell` around line 354)

**Interfaces:**
- Produces: `MediaDetailShell(..., scrollTarget: Binding<String?> = .constant(nil), actions:, content:)`. When it is set to an ID, the shell calls `proxy.scrollTo(id, anchor: UnitPoint(x: 0.5, y: 0.18))` (spring `MarqueeMotion.standard`, none under Reduce Motion), then resets it to nil.

- [ ] **Step 1:** Add the property with a default so `MovieDetailView` compiles unchanged, plus `.onChange(of: scrollTarget.wrappedValue)` inside the `ScrollViewReader`.
- [ ] **Step 2:** Build: `xcodebuild -project Marquee.xcodeproj -scheme Marquee -destination 'generic/platform=iOS Simulator' -quiet build 2>&1 | grep error:` → no output.

---

### Task 3: Segmented Episodes | About switch

**Files:**
- Modify: `ios/Marquee/Features/TV/TVDetailPane.swift`

**Interfaces:**
- Produces: `TVDetailPane` case order `episodes, info`. `title` is `"Episodes"` / `"About"`. `TVDetailPaneSwitcher(pane:enabled:showsSelection:)` keeps its signature (the call sites stay) and renders `Picker("Show sections", selection:) { … }.pickerStyle(.segmented)`. When `showsSelection == false`, it renders the picker disabled with no visible selection: bind it to a throwaway `.constant(nil as TVDetailPane?)` tag set. `preferred(for:)` is unchanged.

- [ ] **Step 1:** Replace the underline switcher body. Keep `Haptics.light()` on change and the `micro` animation (nil under Reduce Motion).
- [ ] **Step 2:** Build (Task 2 command) → no errors.

---

### Task 4: Header block

**Files:**
- Create: `ios/Marquee/Features/TV/TVDetailHeader.swift` (`extension TVDetailView`)
- Modify: `ios/Marquee/Features/TV/TVDetailView.swift`: remove `trackingBlock`, `diaryActions`, `statusChip`, `trackingChipLabel`. Make `pane` internal (drop `private`). Add `@State var scrollTarget: String?` and `@State var flashEpisodeKey: String?`. In `content(_:)`, `actions:` becomes `if diaryReady { header(detail) } else { TVDetailDiaryChromePlaceholder() }` and the shell gets `scrollTarget: $scrollTarget`. `tvMetaParts` appends `TVShowPageLogic.heroScore(ratings)` when present.

**Interfaces:**
- Consumes: `TVHeaderState`, `TVShowPageLogic.headerState(...)` (Task 1), `scrollTarget` (Task 2), `TVDetailPane.episodes` (Task 3).
- Produces: `func header(_ detail: TVDetail) -> some View`, `func startWatching(_ detail: TVDetail) async`, `static func episodeRowID(_ key: String) -> String` returning `"ep-\(key)"` (used by Task 5).

- [ ] **Step 1: Layout per state.** The status card uses `GlassCard` only when tracking. Card content: the state line (`"Up next · S\(s) · E\(e)  \(name)"`, `"Rewatch #\(n)"` + `"original history kept"`, `"Paused at S1 · E4"`, `"Finished"` + `×N` + stars when rated, tap → `showRatingSheet`), then `ProgressTrack` + `"3 of 8 · 38%"` (not for finished). Below it, the action row: `HStack` with a primary button using `PrimaryButtonStyle` and `.frame(maxWidth: .infinity)`, then round 44 pt icon buttons (olive soft circle, `theme.olive` glyph):
  - Primary per state: notStarted → "Start with S1 · E1" (uses the state's season number) → `startWatching`. watching → "Continue" and rewatching → "Continue rewatch", both `NavigationLink` → `TVContinueView(tvId:seed:)`. paused → "Resume" → `resume()`. finished unrated → "Rate the show" → `showRatingSheet = true`. finished rated → no primary; icons align leading. premieres → `Text(label)` in `theme.inkMuted`, no button.
  - Icons: heart (`favorited`, `toggleFavorite`) always. Bookmark (`watchlisted`, `toggleWatchlist`) when the state is `.notStarted` or `.premieres`. Otherwise a `Menu` with `ellipsis`: "Rate show" (unless it's the primary), "Pause" (watching), "Start rewatch" (finished → `showStartRewatchConfirm`), "Cancel rewatch" (rewatching, `role: .destructive` → `showCancelRewatchConfirm`).
  - Accessibility labels: "Favorite"/"Favorited", "Add to watchlist"/"On watchlist", "More actions".
- [ ] **Step 2: `startWatching`** in this order: `selectedSeason = season`, then `await loadSeason()` if `episodes` isn't already that season. Switch `pane = .episodes` with the micro animation. Then `flashEpisodeKey = "\(season)-1"` and `scrollTarget = Self.episodeRowID(flashEpisodeKey!)` after one runloop hop (`await Task.yield()`), so the row exists before the scroll. `Haptics.light()`.
- [ ] **Step 3:** `xcodegen generate` and build → no errors.

---

### Task 5: Episodes tab

**Files:**
- Modify: `ios/Marquee/Features/TV/TVDetailEpisodes.swift`

**Interfaces:**
- Consumes: `seasonCountLine`, `offersWholeShow` (Task 1), `episodeRowID`, `flashEpisodeKey` (Task 4).

- [ ] **Step 1: Top of tab.** Delete the kicker / "Mark as you go" block and the season chip `ScrollView`. Inside the `GlassCard` header, the season row is: leading, a `Menu` listing seasons (label `selectedSeasonName` + `chevron.down`, `.headline`, `theme.ink`) when `seasons.count > 1`, else plain `Text(selectedSeasonName)`. Trailing, `seasonCountLine(...)` (`.caption.weight(.semibold)`, `inkMuted`, monospaced digits), then the ⋯ `Menu`: "Mark season watched" (not complete; disabled when nothing is unwatched) → existing `.markSeason` confirm; "Watch season again" + "Remove season watches" (complete) → existing `performSeasonRewatch` / `.unmarkSeason` confirm; "Mark whole show watched" when `offersWholeShow(seasonCount: seasons.count, canMarkWholeShow:)` → `confirmMarkShow()`. Use `total` = `episodes.count` and `aired` = `airedSeason.count`. Show `ProgressTrack` only when `watchedAiredSeason.count > 0`. The season average goes inline after the count. Delete the `Mark season` / `Whole show` buttons and the `showSeasonActionConfirm` alert path if it's no longer referenced (keep the actions).
- [ ] **Step 2: Rows.**
  - Give the row `.id(Self.episodeRowID(key))`.
  - The circle button gets a 44×44 `contentShape`. Its behavior is unchanged.
  - Second button (row body): if `!ep.hasAired`, do nothing. If `isRewatching`, use today's circle behavior. Else, if `marked`, set `episodeLogTarget = .edit(ep)`, otherwise `.new(ep)`. Accessibility hint: "Opens date, rating and note".
  - Unaired rows: `.opacity(0.55)`, and the circle is disabled.
  - "Up next" becomes `Text("Next")` (`.caption2.weight(.bold)`, `theme.olive`) with no capsule.
  - Background: `isNext ? theme.oliveSoft.opacity(0.6) : .clear`, overlaid with `theme.oliveSoft` at opacity 1 while `flashEpisodeKey == key`. Clear the flash after 1.2 s (`.task(id: flashEpisodeKey)` on the list) with a `.standard` fade, or no animation under Reduce Motion.
- [ ] **Step 3:** Move `BestEpisodesCard` below the `GlassCard`.
- [ ] **Step 4:** Build → no errors.

---

### Task 6: About tab

**Files:**
- Modify: `ios/Marquee/Features/TV/TVDetailView.swift` `infoPane(_:)`

- [ ] **Step 1:** Order: synopsis (`SectionKicker("Synopsis")` + `ExpandableText`), facts line, `WatchProvidersRow`, `CreditsRows`, `MediaCastRail`, "More like this". Remove `RatingsStrip` from TV (keep `ratings` loading; the hero uses it).
- [ ] **Step 2:** Build → no errors.

---

### Task 7: Verify

- [ ] **Step 1:** Unit tests: `xcodebuild test … -only-testing:MarqueeTests` → all pass.
- [ ] **Step 2:** UI tests touching the page: `-only-testing:MarqueeUITests/DiaryLogShotTests` and `MarqueeUITests/LaunchSplashTests` → pass.
- [ ] **Step 3:** Screens: launch on the booted simulator with `-uiTesting -previewTVDetail=<id>` for an untracked show and a multi-season show (light and `-marquee.appearance dark`). Screenshot with `xcrun simctl io booted screenshot`, view each, and check against the spec's table and Global Constraints.
- [ ] **Step 4:** Device: build Debug, install with `devicectl` on the user's iPhone (signed in as the empty test account). Check Start on Blade Runner 2099 lands on E1 with the flash, a row tap opens the log sheet, and the circle marks. Ask the user to confirm the watching/finished states on their main account.
- [ ] **Step 5:** Report to the user, and commit only when asked.
