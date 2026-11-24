/**
 * Pure checks for range-scoped stats (no DB).
 * Run: node backend-server/scripts/test-stats-ranges.js
 */
const assert = require('assert');
const { buildStatsRanges, rangeWindows } = require('../services/statsRanges');
const { periodBounds } = require('../services/statsCalendar');

function test(name, fn) {
  try {
    fn();
    console.log(`ok — ${name}`);
  } catch (err) {
    console.error(`FAIL — ${name}`);
    throw err;
  }
}

const tz = 'America/New_York';
// Wednesday 2026-11-18, 20:00 local
const now = new Date('2026-11-19T01:00:00Z');
const bounds = periodBounds(tz, now);

const ep = (tvId, iso, mins = 45, n = 1) => ({
  tvId,
  seasonNumber: 1,
  episodeNumber: n,
  runtimeMinutes: mins,
  watchedAt: new Date(iso),
});
const film = (movieId, iso, mins = 120, rating = null) => ({
  movieId,
  movieTitle: `Film ${movieId}`,
  movieRuntime: String(mins),
  rating,
  watchedAt: new Date(iso),
});

const episodes = [
  ep(1, '2026-11-17T02:00:00Z', 45, 1), // Mon 21:00 local → this week
  ep(1, '2026-11-17T03:00:00Z', 45, 2), // Mon 22:00 local → this week
  ep(2, '2026-11-03T23:00:00Z', 30, 1), // this month, last week-ish
  ep(2, '2026-03-10T23:00:00Z', 30, 2), // this year
  ep(3, '2024-06-01T23:00:00Z', 60, 1), // older year
];
const rewatches = [{ ...ep(1, '2026-11-18T23:30:00Z', 45, 1) }];
const episodePlays = [...episodes, ...rewatches];
const rawFilms = [
  film(10, '2026-11-18T00:30:00Z', 100), // Tue 19:30 local → this week
  film(11, '2026-11-11T00:30:00Z', 90), // previous week, same weekday span
  film(12, '2025-11-10T00:30:00Z', 110),
];
const tracks = [
  { tvId: 1, tvTitle: 'Show One', tvPosterImage: '/one.jpg' },
  { tvId: 2, tvTitle: 'Show Two' },
];

const ranges = buildStatsRanges({
  episodes,
  episodePlays,
  rawFilms,
  tracks,
  filmMetaMap: new Map(),
  tvMetaMap: new Map(),
  timeZone: tz,
  bounds,
});

test('prior windows cover the same elapsed span', () => {
  const w = rangeWindows(bounds);
  assert.strictEqual(bounds.weekStart, '2026-11-16');
  assert.deepStrictEqual(w.week.previous, { start: '2026-11-09', end: '2026-11-11' });
  assert.deepStrictEqual(w.month.previous, { start: '2026-10-01', end: '2026-10-18' });
  assert.strictEqual(w.year.previous.start, '2025-01-01');
  assert.strictEqual(w.all.previous, null);
});

test('week totals split first watches and rewatches', () => {
  const t = ranges.week.totals;
  assert.strictEqual(t.episodeCount, 2);
  assert.strictEqual(t.rewatchPlays, 1);
  assert.strictEqual(t.episodePlays, 3);
  assert.strictEqual(t.filmCount, 1);
  assert.strictEqual(t.tvMins, 135);
  assert.strictEqual(t.filmMins, 100);
  assert.strictEqual(t.activeDays, 3);
  assert.strictEqual(ranges.week.previous.totalMins, 90);
});

test('week trend has 7 local days with future flags', () => {
  const b = ranges.week.trend.buckets;
  assert.strictEqual(b.length, 7);
  assert.strictEqual(b[0].tvMins, 90); // Monday
  assert.strictEqual(b[1].filmMins, 100); // Tuesday
  assert.strictEqual(b[2].tvMins, 45); // Wednesday rewatch
  assert.strictEqual(b[3].future, true);
});

test('rhythm uses local hours', () => {
  assert.strictEqual(ranges.week.rhythm.byHour[21].tvMins, 45);
  assert.strictEqual(ranges.week.rhythm.byHour[19].filmMins, 100);
});

test('year and all ranges widen', () => {
  assert.strictEqual(ranges.year.totals.episodeCount, 4);
  assert.strictEqual(ranges.year.trend.buckets.length, 12);
  assert.strictEqual(ranges.all.totals.episodeCount, 5);
  assert.strictEqual(ranges.all.trend.unit, 'year');
  assert.deepStrictEqual(
    ranges.all.trend.buckets.map((x) => x.key),
    ['2024', '2025', '2026']
  );
});

test('top shows rank by plays with poster', () => {
  const top = ranges.week.topShows[0];
  assert.strictEqual(top.tvId, '1');
  assert.strictEqual(top.plays, 3);
  assert.strictEqual(top.tvPosterImage, '/one.jpg');
});

test('biggest night needs 2+ titles in range', () => {
  assert.strictEqual(ranges.week.biggestNight.date, '2026-11-16');
  assert.strictEqual(ranges.week.biggestNight.count, 2);
});

test('bulk-import days never win biggest night', () => {
  const bulk = Array.from({ length: 40 }, (_, i) => ep(9, '2026-02-02T15:00:00Z', 45, i + 1));
  const r = buildStatsRanges({
    episodes: [...episodes, ...bulk],
    episodePlays: [...episodePlays, ...bulk],
    rawFilms,
    tracks,
    filmMetaMap: new Map(),
    tvMetaMap: new Map(),
    timeZone: tz,
    bounds,
  });
  assert.notStrictEqual(r.year.biggestNight?.date, '2026-02-02');
});

console.log('all stats range checks passed');
