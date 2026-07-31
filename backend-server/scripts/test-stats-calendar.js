/**
 * Lightweight Node assert suite for stats calendar + film dedupe.
 * Run: node scripts/test-stats-calendar.js
 */
const assert = require('assert');
const {
  resolveTimeZone,
  dateKeyInZone,
  mondayWeekContaining,
  periodBounds,
  computeStreakFromDaySet,
  longestStreakFromDaySet,
  trailingMonthKeys,
  addDaysToKey,
  calendarWeeklyTrend,
  busiestWeekdayFromDayKeys,
  weekdayOfKey,
} = require('../services/statsCalendar');
const { dedupeFilms } = require('../services/filmDedupe');

function test(name, fn) {
  try {
    fn();
    console.log(`ok - ${name}`);
  } catch (err) {
    console.error(`fail - ${name}`);
    throw err;
  }
}

test('resolveTimeZone falls back for invalid zones', () => {
  assert.strictEqual(resolveTimeZone('Not/AZone'), 'UTC');
  assert.strictEqual(resolveTimeZone('America/Toronto'), 'America/Toronto');
});

test('dateKeyInZone uses local calendar day', () => {
  // 2024-01-01 03:00 UTC is still 2023-12-31 evening in America/Los_Angeles
  const instant = new Date('2024-01-01T03:00:00.000Z');
  assert.strictEqual(dateKeyInZone(instant, 'UTC'), '2024-01-01');
  assert.strictEqual(dateKeyInZone(instant, 'America/Los_Angeles'), '2023-12-31');
});

test('mondayWeekContaining returns Monday–Sunday', () => {
  // Wednesday 2024-07-03 in Toronto
  const wed = new Date('2024-07-03T18:00:00.000Z');
  const { weekStart, weekEnd } = mondayWeekContaining(wed, 'America/Toronto');
  assert.strictEqual(weekStart, '2024-07-01');
  assert.strictEqual(weekEnd, '2024-07-07');
  assert.strictEqual(weekdayOfKey(weekStart, 'America/Toronto'), 1);
});

test('periodBounds year/month/week are Monday-based', () => {
  const now = new Date('2024-07-03T18:00:00.000Z');
  const b = periodBounds('America/Toronto', now);
  assert.strictEqual(b.weekStart, '2024-07-01');
  assert.strictEqual(b.monthStart, '2024-07-01');
  assert.strictEqual(b.yearStart, '2024-01-01');
});

test('computeStreakFromDaySet allows yesterday grace', () => {
  const today = '2024-07-03';
  const set = new Set(['2024-07-02', '2024-07-01']);
  assert.strictEqual(computeStreakFromDaySet(set, today), 2);
  set.add('2024-07-03');
  assert.strictEqual(computeStreakFromDaySet(set, today), 3);
  assert.strictEqual(computeStreakFromDaySet(new Set(), today), 0);
});

test('longestStreakFromDaySet finds best historical run', () => {
  const set = new Set([
    '2024-01-01',
    '2024-01-02',
    '2024-01-03',
    '2024-03-10',
    '2024-03-11',
  ]);
  assert.strictEqual(longestStreakFromDaySet(set), 3);
  assert.strictEqual(longestStreakFromDaySet(new Set()), 0);
  assert.strictEqual(longestStreakFromDaySet(new Set(['2024-05-05'])), 1);
});

test('longestStreakFromDaySet spans month and year borders', () => {
  const set = new Set(['2023-12-30', '2023-12-31', '2024-01-01', '2024-01-02']);
  assert.strictEqual(longestStreakFromDaySet(set), 4);
});

test('trailingMonthKeys wraps across the year boundary', () => {
  const keys = trailingMonthKeys('America/Toronto', 3, new Date('2024-02-15T18:00:00.000Z'));
  assert.deepStrictEqual(keys, ['2023-12', '2024-01', '2024-02']);
  assert.strictEqual(trailingMonthKeys('UTC', 12).length, 12);
});

test('calendarWeeklyTrend uses Monday weekStarts', () => {
  const dayMap = {
    '2024-07-01': { episodes: 2, films: 1, tvMinutes: 90, filmMinutes: 120 },
    '2024-07-03': { episodes: 1, films: 0, tvMinutes: 45, filmMinutes: 0 },
  };
  const now = new Date('2024-07-03T18:00:00.000Z');
  const trend = calendarWeeklyTrend(dayMap, 'America/Toronto', 2, now);
  assert.strictEqual(trend.length, 2);
  const current = trend[trend.length - 1];
  assert.strictEqual(current.weekStart, '2024-07-01');
  assert.strictEqual(current.episodes, 3);
  assert.strictEqual(current.films, 1);
  assert.strictEqual(current.minutes, 255);
});

test('busiestWeekdayFromDayKeys picks max lifetime weekday', () => {
  const result = busiestWeekdayFromDayKeys([
    { key: '2024-07-01', count: 2, weekday: 1 },
    { key: '2024-07-08', count: 3, weekday: 1 },
    { key: '2024-07-02', count: 4, weekday: 2 },
  ]);
  assert.strictEqual(result.day, 'Monday');
  assert.strictEqual(result.count, 5);
});

test('dedupeFilms keeps newest row per movieId', () => {
  const films = [
    { movieId: '1', movieTitle: 'A', watchedAt: '2024-01-01' },
    { movieId: '1', movieTitle: 'A again', watchedAt: '2024-06-01' },
    { movieId: '2', movieTitle: 'B', watchedAt: '2024-02-01' },
  ];
  const out = dedupeFilms(films);
  assert.strictEqual(out.length, 2);
  assert.strictEqual(out.find((f) => f.movieId === '1').movieTitle, 'A again');
});

test('addDaysToKey crosses month boundaries', () => {
  assert.strictEqual(addDaysToKey('2024-01-31', 1), '2024-02-01');
  assert.strictEqual(addDaysToKey('2024-02-01', -1), '2024-01-31');
});

console.log('\nAll stats calendar tests passed.');
