/**
 * Pure checks for the Home feed schedule helpers (no DB).
 * Run: node backend-server/scripts/test-home-feed.js
 */
const assert = require('assert');
const {
  dayKey, addDays, upcomingFromSeason, firstReturnFromSeason, nextAirDateFor, mergeAgenda,
} = require('../services/homeFeed');

function test(name, fn) {
  try {
    fn();
    console.log(`ok — ${name}`);
  } catch (err) {
    console.error(`FAIL — ${name}`);
    throw err;
  }
}

const track = { tvId: '42', tvTitle: 'Silo', tvPosterImage: '/p.jpg', nextSeason: 1, nextEpisode: 8 };
const ep = (n, air) => ({ episode_number: n, season_number: 1, name: `E${n}`, air_date: air });

test('dayKey follows the user timezone', () => {
  const late = new Date('2026-11-25T03:30:00Z');
  assert.strictEqual(dayKey(late, 'America/New_York'), '2026-11-24');
  assert.strictEqual(dayKey(late, 'UTC'), '2026-11-25');
});

test('addDays crosses months', () => {
  assert.strictEqual(addDays('2026-11-28', 3), '2026-12-01');
});

test('upcomingFromSeason keeps today through +7 days', () => {
  const season = { episodes: [ep(7, '2026-11-23'), ep(8, '2026-11-24'), ep(9, '2026-12-01'), ep(10, '2026-12-02')] };
  const out = upcomingFromSeason(track, season, '2026-11-24');
  assert.deepStrictEqual(out.map((e) => e.episode), [8, 9]);
  assert.strictEqual(out[0].tvId, 42);
  assert.strictEqual(out[0].title, 'Silo');
  assert.strictEqual(out[0].kind, 'airing');
});

test('firstReturnFromSeason honours the 30-day window', () => {
  assert.ok(firstReturnFromSeason(track, { season_number: 2, episodes: [ep(1, '2026-12-20')] }, '2026-11-24'));
  assert.strictEqual(firstReturnFromSeason(track, { season_number: 2, episodes: [ep(1, '2026-12-30')] }, '2026-11-24'), null);
});

test('nextAirDateFor matches the next episode only', () => {
  const agenda = upcomingFromSeason(track, { episodes: [ep(8, '2026-11-24')] }, '2026-11-24');
  assert.strictEqual(nextAirDateFor(track, agenda), '2026-11-24');
  assert.strictEqual(nextAirDateFor({ ...track, nextEpisode: 9 }, agenda), null);
});

test('mergeAgenda drops returns for shows already airing and sorts', () => {
  const a = { tvId: 1, airDate: '2026-11-26', kind: 'airing' };
  const b = { tvId: 2, airDate: '2026-11-25', kind: 'airing' };
  const r1 = { tvId: 1, airDate: '2026-12-01', kind: 'returning' };
  const r2 = { tvId: 3, airDate: '2026-11-30', kind: 'returning' };
  assert.deepStrictEqual(mergeAgenda([a, b], [r1, r2]).map((e) => e.tvId), [2, 1, 3]);
});
