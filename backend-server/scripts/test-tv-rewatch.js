/**
 * Pure logic checks for TV rewatch helpers (no DB).
 * Run: node backend-server/scripts/test-tv-rewatch.js
 */
const assert = require('assert');
const { sessionPayload, episodeSort } = require('../services/tvRewatchService');

function test(name, fn) {
  try {
    fn();
    console.log(`ok — ${name}`);
  } catch (err) {
    console.error(`FAIL — ${name}`);
    throw err;
  }
}

test('sessionPayload exposes string id and episodeCount', () => {
  const payload = sessionPayload(
    {
      _id: { toString: () => 'abc123' },
      tvId: '1396',
      sessionNumber: 1,
      status: 'active',
      watchedEpisodeCount: 0,
    },
    [{ seasonNumber: 1, episodeNumber: 1 }]
  );
  assert.strictEqual(payload.id, 'abc123');
  assert.strictEqual(payload.episodeCount, 1);
  assert.strictEqual(payload.status, 'active');
});

test('episodeSort orders by season then episode', () => {
  const rows = [
    { seasonNumber: 2, episodeNumber: 1 },
    { seasonNumber: 1, episodeNumber: 3 },
    { seasonNumber: 1, episodeNumber: 1 },
  ].sort(episodeSort);
  assert.deepStrictEqual(
    rows.map((r) => `${r.seasonNumber}-${r.episodeNumber}`),
    ['1-1', '1-3', '2-1']
  );
});

test('tracking status enum includes rewatching in model file', () => {
  const src = require('fs').readFileSync(
    require('path').join(__dirname, '../models/tvShowTracking.js'),
    'utf8'
  );
  assert.ok(src.includes("'rewatching'"));
  assert.ok(src.includes('timesCompleted'));
  assert.ok(src.includes('activeRewatchSessionId'));
});

console.log('All TV rewatch tests passed.');
