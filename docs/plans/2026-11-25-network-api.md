# Network & API plan — execution

Source: "Marquee Network & API Plan" doc (https://claude.ai/artifact/EsNXGbmU1wSx1sVRUNTRVi), findings #1–#23.
Spec: that doc. Branch: `perf/network-plan`.

Global constraints
- Backend tests are plain Node assert scripts in `backend-server/scripts/test-*.js` (no DB, no framework). Suite: `for f in backend-server/scripts/test-*.js; do node $f || exit 1; done`.
- iOS tests: `xcodebuild test -project ios/Marquee.xcodeproj -scheme Marquee -destination 'id=043E452A-4D81-4962-82ED-4EE33267FA40' -only-testing:MarqueeTests`.
- Old iOS builds in the field must keep working: never remove or change the shape of an existing route; add new ones beside them.
- JS style per CLAUDE.md: `if (`, spaces around `=`, braces on the same line. Commit messages: short imperative sentence, no co-author trailer.
- Any route that changes watch data still calls `invalidateUserStats(userId)`.

## Task 1: Request timing, slow-request log and event-loop lag (Phase 0)
Files: `backend-server/lib/metrics.js` (new), `backend-server/app.js`, `backend-server/scripts/test-metrics.js` (new), `backend-server/scripts/load-test.js` (new).
- `metrics.js` exports `requestTimer({ slowMs, log })` middleware (adds `Server-Timing: app;dur=<ms>` header, logs `[slow] METHOD path status ms` when over `slowMs`, never logs query strings) and `startLoopMonitor()` returning `{ snapshot() }` with p50/p99/max event-loop delay in ms.
- `app.js`: use `requestTimer({ slowMs: 500 })`; `morgan('dev')` only outside production, `morgan('tiny')` in production; `/health` adds `loop` snapshot.
- `load-test.js`: N concurrent virtual users for D seconds against `BASE_URL` with `TOKEN`, paths from argv; prints count, p50/p95/max, error count.
Test: `node backend-server/scripts/test-metrics.js` — middleware sets Server-Timing, slow log fires above threshold only, path without query string.
Expected: `metrics: all passed`.

## Task 2: Bounded streak query for the week recap (#3)
Files: `backend-server/services/weekRecap.js`, `backend-server/scripts/test-week-recap.js` (new), `backend-server/scripts/check-recap-parity.js` (new, read-only DB check).
- Replace the three whole-history `find`s with one aggregation per collection that returns distinct day keys in the user's timezone (`$dateToString` with `timezone`, `$group`), then feed `computeStreakFromDaySet`.
- Pure helper `dayKeysPipeline(userId, timeZone)` exported and unit tested.
Test: `node backend-server/scripts/test-week-recap.js`; parity: `node backend-server/scripts/check-recap-parity.js` → new recap equals old recap for every user.
Expected: tests pass; parity `0 mismatches`.

## Task 3: Stats cache — single flight and stale-while-rebuild (#2)
Files: `backend-server/lib/singleFlight.js` (new), `backend-server/services/statsCache.js`, `backend-server/models/userStatsCache.js`, `backend-server/routes/stats.js`, `backend-server/scripts/test-stats-cache.js` (new).
- `singleFlight()` shares one in-flight promise per key.
- `invalidateUserStats` sets `staleAt` instead of deleting.
- Dashboard: fresh cache → return; stale cache → return it (`stale: true`) and rebuild in the background at most once per 60 s per user; no cache or `refresh=1` → build through single flight.
Test: `node backend-server/scripts/test-stats-cache.js` (decision function + single flight).
Expected: `stats cache: all passed`.

## Task 4: Auto-pause at most once a day per user (#5)
Files: `backend-server/services/tvTrackingMaintenance.js`, `backend-server/scripts/test-maintenance.js` (new).
- `autoPauseStaleTracks(userId, { now })` returns early when it ran for that user in the last 24 h (in-memory map, bounded).
Test: `node backend-server/scripts/test-maintenance.js`.
Expected: second call within 24 h does no query.

## Task 5: Missing userFrom indexes (#12)
Files: `backend-server/models/favorite.js`, `favoritefortv.js`, `moviewatchlist.js`, `tvwatchlist.js`, `backend-server/services/tvWatchlistService.js`, `backend-server/scripts/test-indexes.js` (new).
- Add `{ userFrom: 1, movieId|tvId: 1 }` indexes; `clearWatchlistForShow` uses an indexed exact delete first, scan only as fallback.
Test: `node backend-server/scripts/test-indexes.js` (schema.indexes() contains the keys).
Expected: `indexes: all passed`.

## Task 6: TMDB layer — bounded cache, coalescing, timeout, concurrency (#6)
Files: `backend-server/lib/tmdbClient.js` (new), `backend-server/lib/tmdb.js`, `backend-server/routes/tmdb.js`, `backend-server/services/tmdbCache.js`, `backend-server/scripts/test-tmdb-client.js` (new).
- One client: byte-bounded LRU with per-entry TTL, single flight per URL, `AbortSignal.timeout(8000)`, max 8 concurrent upstream requests, one retry after `Retry-After` on 429.
- `lib/tmdb.js` and the proxy route both use it; remove the unbounded `memoryCache` and the racy throttle.
Test: `node backend-server/scripts/test-tmdb-client.js` (fake fetch: coalescing, byte eviction, TTL, concurrency cap, 429 retry, timeout).
Expected: `tmdb client: all passed`; existing `test-tmdb-cache.js` still passes.

## Task 7: Rate limiting (#14)
Files: `backend-server/lib/rateLimit.js` (new), `backend-server/app.js`, `backend-server/scripts/test-rate-limit.js` (new).
- Small in-memory fixed-window limiter (no new dependency): auth routes 20/15 min per IP, TMDB proxy 300/min per IP, everything else 600/min per IP; `app.set('trust proxy', 1)`; 429 JSON `{ success:false, message }` with `Retry-After`.
Test: `node backend-server/scripts/test-rate-limit.js`.
Expected: `rate limit: all passed`.

## Task 8: Auth loads only what it needs (#13)
Files: `backend-server/authenticate.js`.
- `User.findById(id).select('-hash -salt')`.
Test: backend suite.
Expected: suite passes.

## Task 9: iOS Home and You refetch only when stale (#4)
Files: `ios/Marquee/Core/Freshness.swift` (new), `ios/Marquee/Features/Home/HomeView.swift`, `ios/Marquee/Features/Profile/ProfileView.swift`, `ios/MarqueeTests/FreshnessTests.swift` (new).
- `Freshness` (60 s window, `markStale()`); `.task` loads only when stale; pull-to-refresh and mutations force.
Test: iOS suite.
Expected: tests pass.

## Task 10: Mutations return state; show page stops refetching (#9)
Files: `ios/Marquee/Features/TV/TVDetailView.swift`, `ios/Marquee/Core/DiaryService.swift`.
- Use the tracking returned by mark/unmark/stop/resume instead of a follow-up `tracking` GET.
Test: iOS suite. Expected: pass.

## Task 11: Per-user state endpoints for detail pages (#8)
Files: `backend-server/routes/me.js` (new), `backend-server/app.js`, iOS `DiaryService.swift`, `TVDetailView.swift`, `MovieDetailView.swift`, `backend-server/scripts/test-me-shape.js` (new).
- `GET /api/me/tv/:tvId` → `{ favorited, watchlisted, tracking, episodes, rewatch }`; `GET /api/me/movie/:movieId` → `{ favorited, watchlisted, watched }`. iOS uses them, falling back to the old calls on 404.
Test: shape builders unit tested; iOS suite. Expected: pass.

## Task 12: Diary index with ETag and GET list routes (#10, #11)
Files: `backend-server/routes/diary.js`, `backend-server/lib/etag.js` (new), list routes, iOS `FilmDiaryIndex.swift`, `DiaryService.swift`, `backend-server/scripts/test-etag.js` (new).
- `GET /api/diary/index` → `{ films: [[id, count, rating]], filmWatchlist: [id] }` with weak ETag + 304. GET aliases for `getWatchMovie`, `getMovieWatchlist`, `getWatchTv`, `getFavorite*`.
Test: `node backend-server/scripts/test-etag.js`. Expected: pass.

## Task 13: Ratings persisted with a TTL (#7)
Files: `backend-server/models/ratingsCache.js` (new), `backend-server/routes/ratings.js`.
- Mongo-backed cache (TTL index 24 h) behind a bounded in-memory LRU; single flight.
Test: backend suite. Expected: pass.

## Task 14: iOS networking — session, GET de-duplication, retry (#20–#23)
Files: `ios/Marquee/Core/APIClient.swift`, `ios/MarqueeTests/APIClientTests.swift` (new).
- Dedicated `URLSession` (15 s request timeout, `waitsForConnectivity`, 20 MB/100 MB URLCache); identical in-flight GETs share one task; GETs retry up to twice on transport errors and 502/503/504 with backoff; decoding moves out of the actor.
Test: iOS suite with a URLProtocol stub. Expected: pass.

## Task 15: Hardening — errors, JWT secret, graceful shutdown, helmet-style headers (#15–#18)
Files: `backend-server/app.js`, `backend-server/config/keys.js`, `backend-server/bin/www`, `backend-server/package.json`.
- 500s return a generic message; production refuses to start without `JWT_SECRET`; SIGTERM closes the server then Mongo; Express to latest 4.x; basic security headers.
Test: backend suite + `node -e "require('./app')"` boots. Expected: pass.
