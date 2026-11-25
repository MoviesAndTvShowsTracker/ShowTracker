/* Stats cache: serve fresh, serve stale while rebuilding (throttled), build when missing. No DB. */
const assert = require('assert');
const { statsCacheDecision, isStale } = require('../services/statsCache');
const { singleFlight } = require('../lib/singleFlight');

const tz = 'America/New_York';
const v = 7;
const t0 = new Date('2026-11-25T12:00:00Z');
const at = (s) => new Date(t0.getTime() + s * 1000);
const cached = (extra = {}) => ({ stats: { timeZone: tz, schemaVersion: v }, builtAt: t0, staleAt: null, ...extra });
const decide = (c, extra = {}) => statsCacheDecision({ cached: c, timeZone: tz, schemaVersion: v, forceRefresh: false, now: at(10), lastRebuildAt: null, ...extra });

(async () => {
  assert.strictEqual(decide(null), 'build', 'nothing cached');
  assert.strictEqual(decide(cached()), 'serve', 'fresh cache');
  assert.strictEqual(decide(cached(), { forceRefresh: true }), 'build', 'pull to refresh');
  assert.strictEqual(decide(cached({ stats: { timeZone: 'Asia/Kolkata', schemaVersion: v } })), 'build', 'other timezone');
  assert.strictEqual(decide(cached({ stats: { timeZone: tz, schemaVersion: v - 1 } })), 'build', 'old payload');

  // A mark after the build started makes it stale: serve it, rebuild behind.
  const stale = cached({ staleAt: at(5) });
  assert.ok(isStale(stale));
  assert.strictEqual(decide(stale), 'serve-and-rebuild');
  // Rebuilt less than a minute ago: just serve.
  assert.strictEqual(decide(stale, { lastRebuildAt: at(-30) }), 'serve');
  assert.strictEqual(decide(stale, { lastRebuildAt: at(-61) }), 'serve-and-rebuild');
  // A mark before the build started is already included.
  assert.ok(!isStale(cached({ staleAt: at(-5) })));

  // Single flight: concurrent callers share one run; a later call runs again.
  let runs = 0;
  const work = () => new Promise((r) => setTimeout(() => { runs += 1; r(runs); }, 20));
  const results = await Promise.all([singleFlight('k', work), singleFlight('k', work), singleFlight('k', work)]);
  assert.deepStrictEqual(results, [1, 1, 1]);
  assert.strictEqual(await singleFlight('k', work), 2);
  // A failure is shared too, and the key is released afterwards.
  await assert.rejects(Promise.all([singleFlight('e', () => Promise.reject(new Error('boom'))), singleFlight('e', work)]), /boom/);
  assert.strictEqual(await singleFlight('e', work), 3);

  console.log('stats cache: all passed');
})().catch((err) => {
  console.error(err);
  process.exit(1);
});
