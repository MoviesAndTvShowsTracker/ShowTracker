# TV show page redesign

## Intent

The show page (`Features/TV/TVDetailView`, `TVDetailEpisodes`, `TVDetailPane`) reads as stacked-up parts: a "Your diary" card holding two pills, a whole "Scores" section for one number, an "EPISODES / Mark as you go" header that repeats the tab, a hot-pink "Whole show" button that is the loudest thing on a show you haven't started, and rows where a tap anywhere marks the episode watched. "Mark an episode to start" switches tabs but leaves you wherever you were scrolled.

Goal: a calm page with one obvious next action per state, the episode list as the core tool, and catalogue info out of the way until wanted. It should feel like one designed product, not a pile of features.

## Goals

- One primary action per state, in hibiscus. Everything else quiet.
- Starting a show: the button takes you to S1 · E1, scrolls it into view and highlights it. You mark it yourself. (User's call.)
- Marking only happens on the mark circle or from explicit menus, never by brushing a row.
- No section header that repeats its tab or its content.
- Keep every existing capability: mark, mark up to here, log with date/rating/note, edit log, rewatch (start, cancel, per-episode, per-season), pause/resume, mark season, unmark season, mark whole show, show rating, favorite, watchlist, best episodes, season average, notes, play counts.

## Non-goals

- Film detail page. It shares `MediaDetailShell`, `RatingsStrip` and `DiaryGlassStrip`; those stay as they are for films. (Follow-up: bring the same treatment to films so the two pages match.)
- Continue screen, Home, server/API.

## Anti-goals

- Hiding an existing feature so deeply people think it's gone.
- A second accent, glass on rows, or decoration added to fill space.
- Layout jumps while tracking/diary loads (keep the existing placeholders' role).

## Approaches considered

- **A. Polish in place.** Fix the specific issues and keep the structure. Cheapest, but the assembled feel stays.
- **B. One long page, episodes first** (Apple TV style). Starting is one scroll, but cast and similar shows end up far below a long episode list on multi-season shows.
- **C. Keep two tabs, rebuild what's around and inside them.** **Chosen.** The tab split already scales to long shows and opens on the right tab for each state (`TVDetailPane.preferred`). The problem is clutter, not structure.

## Design

### Hero

Unchanged shell. The meta line gains the score: `2026 · 1 season · ★ 4.5 TMDB` (IMDb if present, else TMDB, else nothing). The genres line stays.

### Header block (replaces `trackingBlock` + `DiaryGlassStrip`)

One row: a primary button that fills the width, then round icon buttons. Above it, only when tracking, a short status card.

| State | Status card | Primary button | Icons |
|---|---|---|---|
| Not started | none | **Start with S1 · E1** | ♡ favorite, bookmark watchlist |
| Watching | "Up next · S1 · E4 Name", progress bar, "3 of 8 · 38%" | **Continue** → `TVContinueView` | ♡, ⋯ |
| Rewatching | same, labelled "Rewatch #2", "original history kept" caption | **Continue rewatch** | ♡, ⋯ |
| Paused | "Paused at S1 · E4", progress | **Resume** | ♡, ⋯ |
| Completed | "Finished" (×N if > 1), your show stars if rated | **Rate the show** if unrated, otherwise none (card shows stars, tap edits) | ♡, ⋯ |

- ⋯ menu holds the less frequent actions for the state: Rate show (when not the primary), Pause, Cancel rewatch (destructive), Start rewatch. Every one reuses the existing confirm alerts.
- The watchlist icon only shows when not tracking, matching the current rule (status replaces watchlist).
- "Start with S1 · E1": uses the first season with aired episodes, sets `selectedSeason`, switches to Episodes, loads the season if needed, scrolls E1 to the top of the visible area and flashes its row (olive soft tint, ~1.2 s fade; no flash under Reduce Motion, scroll without animation).
- No "Your diary" kicker. The old status chip that duplicated "Continue" goes away.

### Tabs

Native segmented `Picker`: **Episodes | About**. Episodes first because it's the core tool. The initial-tab rule and no-jump loading stay.

### Episodes tab

- No kicker and no "Mark as you go".
- Season row: a season `Menu` ("Season 1 ▾", or the season name, e.g. "Miniseries") when there's more than one season, plain text when only one. On the right: "3 of 8 watched", plus "· 2 to air" when some haven't aired. Then a ⋯ menu with: Mark season watched / Watch season again + Remove season watches (when complete) / Mark whole show watched (only when the show has more than one season and unwatched aired episodes). These reuse the existing batch confirms. The big Mark season / Whole show buttons go away.
- A thin progress bar under the season row only once something in the season is watched. Season average (★) sits on the same line as the count when present.
- Rows:
  - The mark circle is the only one-tap mark (44 pt tap target). Behaviour unchanged: unwatched → mark; watched → the existing "watch again / edit / remove" alert.
  - Tapping the rest of the row opens the log sheet: `.new` for unwatched (date, rating, note), `.edit` for watched. In rewatch mode the row tap does what the circle does, as today.
  - "Up next" becomes small olive text beside the code, and the row keeps its soft tint.
  - Same content otherwise (still, code + name, air date, runtime, watched date, note, synopsis 2 lines, stars). The context menu stays.
- `BestEpisodesCard` moves below the episode list.

### About tab

Order: synopsis (expandable), facts line (status · N episodes · network), where to watch, creators/writing, cast, more like this. No Scores section (it's in the hero).

### Shell change

`MediaDetailShell` gets an optional scroll request (e.g. `scrollTarget: Binding<String?>`) so the TV page can ask its `ScrollViewReader` to scroll to an episode row ID. Films pass nothing.

## Constraints

- `ios/DESIGN.md`: hibiscus only for actions/progress, no glass on rows, springs 100–250 ms, Reduce Motion respected, SF Pro, short diary copy.
- Run `xcodegen generate` if files are added. Don't hand-edit the pbxproj.
- Existing UI tests that reference TV detail identifiers must keep passing, or be updated deliberately.

## Edge cases (designer's calls)

- **Nothing has aired yet** (announced show): no Start button. The header shows quiet text "Premieres Dec 3" (or "Not aired yet" without a date), plus ♡ and the watchlist icon.
- **Unaired episode rows**: the circle and row tap do nothing, and the row is dimmed slightly. This matches the existing rule that batch marks skip unaired episodes.
- **`dropped` status**: treated like Paused ("Stopped at S1 · E4", **Resume**). Today it falls through to a generic card.
- The only UI test that touches the page is the `DiaryLogShotTests` screenshot. Re-run it and look at the output.

## Left to the builder

- Exact spacing, icon sizes and whether the icon buttons use `.glass` button style (they're chrome-like; allowed) or olive-soft circles.
- Copy polish within the diary voice.
- Splitting `TVDetailView.swift` (1,358 lines) into a header file while touching it.
