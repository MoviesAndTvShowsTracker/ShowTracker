/**
 * Pure unit checks for multi-play film watch helpers (no DB).
 * Run: node backend-server/scripts/test-film-watch-plays.js
 */
const assert = require('assert');
const {
  summarizePlays,
  libraryFilmsFromPlays,
  sortPlaysNewestFirst,
} = require('../services/filmWatchService');

function test(name, fn) {
  try {
    fn();
    console.log(`ok — ${name}`);
  } catch (err) {
    console.error(`FAIL — ${name}`);
    throw err;
  }
}

test('summarizePlays keeps newest date without inventing data', () => {
  const first = {
    _id: 'a',
    movieId: '1',
    watchedAt: new Date('2024-01-10T12:00:00Z'),
    rating: 8,
    isRewatch: false,
  };
  const second = {
    _id: 'b',
    movieId: '1',
    watchedAt: new Date('2026-11-22T18:00:00Z'),
    rating: null,
    isRewatch: true,
  };
  const summary = summarizePlays([first, second]);
  assert.strictEqual(summary.watchCount, 2);
  assert.strictEqual(summary.watched, true);
  assert.strictEqual(summary.isRewatch, true);
  assert.strictEqual(new Date(summary.watchedAt).toISOString(), '2026-11-22T18:00:00.000Z');
  assert.strictEqual(summary.rating, null);
  assert.strictEqual(summary.latestPlayId, 'b');
});

test('removing newest conceptually leaves first date (sort order)', () => {
  const first = {
    _id: 'a',
    movieId: '1',
    watchedAt: new Date('2024-01-10T12:00:00Z'),
    isRewatch: false,
  };
  const second = {
    _id: 'b',
    movieId: '1',
    watchedAt: new Date('2026-11-22T18:00:00Z'),
    isRewatch: true,
  };
  const remaining = sortPlaysNewestFirst([first, second]).slice(1);
  const summary = summarizePlays(remaining);
  assert.strictEqual(summary.watchCount, 1);
  assert.strictEqual(summary.isRewatch, false);
  assert.strictEqual(new Date(summary.watchedAt).toISOString(), '2024-01-10T12:00:00.000Z');
  assert.strictEqual(summary.latestPlayId, 'a');
});

test('libraryFilmsFromPlays collapses to one row with watchCount', () => {
  const plays = [
    {
      _id: 'b',
      movieId: '1',
      movieTitle: 'Inception',
      watchedAt: new Date('2026-11-22'),
      isRewatch: true,
    },
    {
      _id: 'a',
      movieId: '1',
      movieTitle: 'Inception',
      watchedAt: new Date('2024-01-10'),
      isRewatch: false,
    },
    {
      _id: 'c',
      movieId: '2',
      movieTitle: 'Dune',
      watchedAt: new Date('2025-06-01'),
      isRewatch: false,
    },
  ];
  const library = libraryFilmsFromPlays(plays);
  assert.strictEqual(library.length, 2);
  const inception = library.find((f) => f.movieId === '1');
  assert.strictEqual(inception.watchCount, 2);
  assert.strictEqual(inception.isRewatch, true);
  assert.strictEqual(new Date(inception.watchedAt).toISOString().startsWith('2026-11-22'), true);
});

console.log('All film watch play tests passed.');
