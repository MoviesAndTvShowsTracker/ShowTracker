/**
 * Pure logic checks for TV rewatch helpers (no DB).
 * Run: node backend-server/scripts/test-tv-rewatch.js
 */
const assert = require('assert');
const { sessionPayload, episodeSort } = require('../services/tvRewatchService');
const { clusterRewatchSessions, expandAnthologySplits } = require('./tvtime-lib');

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

test('clusterRewatchSessions dedupes identical marks and splits on episode repeat', () => {
  const plays = [
    { seasonNumber: 1, episodeNumber: 1, watchedAt: new Date('2020-01-01T10:00:00Z') },
    { seasonNumber: 1, episodeNumber: 1, watchedAt: new Date('2020-01-01T10:00:00Z') }, // dup
    { seasonNumber: 1, episodeNumber: 2, watchedAt: new Date('2020-01-02T10:00:00Z') },
    { seasonNumber: 1, episodeNumber: 1, watchedAt: new Date('2020-03-01T10:00:00Z') }, // new run
    { seasonNumber: 1, episodeNumber: 2, watchedAt: new Date('2020-03-02T10:00:00Z') },
  ];
  const sessions = clusterRewatchSessions(plays, { gapDays: 30 });
  assert.strictEqual(sessions.length, 2);
  assert.strictEqual(sessions[0].length, 2);
  assert.strictEqual(sessions[1].length, 2);
});

test('clusterRewatchSessions splits on long gaps', () => {
  const plays = [
    { seasonNumber: 1, episodeNumber: 1, watchedAt: new Date('2020-01-01T10:00:00Z') },
    { seasonNumber: 1, episodeNumber: 2, watchedAt: new Date('2020-01-02T10:00:00Z') },
    { seasonNumber: 1, episodeNumber: 3, watchedAt: new Date('2020-05-01T10:00:00Z') },
  ];
  const sessions = clusterRewatchSessions(plays, { gapDays: 30 });
  assert.strictEqual(sessions.length, 2);
  assert.strictEqual(sessions[0].length, 2);
  assert.strictEqual(sessions[1].length, 1);
});

test('expandAnthologySplits maps Haunting S2 onto Bly Manor S1', () => {
  const [hill, bly] = expandAnthologySplits([
    { tvdbId: '345246', seasonNumber: 1, episodeNumber: 1, seriesName: 'The Haunting' },
    { tvdbId: '345246', seasonNumber: 2, episodeNumber: 3, seriesName: 'The Haunting' },
  ]);
  assert.strictEqual(hill.forcedMapping.tmdbId, '72844');
  assert.strictEqual(hill.seasonNumber, 1);
  assert.strictEqual(bly.forcedMapping.tmdbId, '109958');
  assert.strictEqual(bly.seasonNumber, 1);
  assert.strictEqual(bly.episodeNumber, 3);
});

test('tvRewatchService exports play-count helpers', () => {
  const svc = require('../services/tvRewatchService');
  assert.equal(typeof svc.getEpisodePlayCounts, 'function');
  assert.equal(typeof svc.logEpisodeRewatches, 'function');
  assert.equal(typeof svc.undoEpisodePlay, 'function');
  assert.equal(typeof svc.computeTimesCompleted, 'function');
  assert.equal(typeof svc.repairTimesCompletedForUser, 'function');
});

console.log('All TV rewatch tests passed.');
