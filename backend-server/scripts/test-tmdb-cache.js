/**
 * Pure checks for the TMDB proxy cache (no network).
 * Run: node backend-server/scripts/test-tmdb-cache.js
 */
const assert = require('assert');
const { createTmdbCache, ttlFor } = require('../services/tmdbCache');

function test(name, fn) {
  try {
    fn();
    console.log(`ok — ${name}`);
  } catch (err) {
    console.error(`FAIL — ${name}`);
    throw err;
  }
}

test('lists refresh every 10 minutes', () => {
  assert.strictEqual(ttlFor('trending/movie/week'), 10 * 60);
  assert.strictEqual(ttlFor('movie/popular'), 10 * 60);
  assert.strictEqual(ttlFor('discover/tv'), 10 * 60);
});

test('search refreshes every 5 minutes', () => {
  assert.strictEqual(ttlFor('search/multi'), 5 * 60);
});

test('title details last a day', () => {
  assert.strictEqual(ttlFor('movie/27205'), 24 * 60 * 60);
  assert.strictEqual(ttlFor('tv/1396/season/2'), 24 * 60 * 60);
});

test('watch providers refresh every 6 hours', () => {
  assert.strictEqual(ttlFor('movie/27205/watch/providers'), 6 * 60 * 60);
});

test('cache returns fresh entries and drops expired ones', () => {
  let now = 1000;
  const cache = createTmdbCache({ maxEntries: 10, now: () => now });
  cache.set('k', { status: 200, body: '{}' }, 60);
  assert.deepStrictEqual(cache.get('k'), { status: 200, body: '{}' });
  now += 61 * 1000;
  assert.strictEqual(cache.get('k'), undefined);
});

test('cache evicts the least recently used entry when full', () => {
  const cache = createTmdbCache({ maxEntries: 2, now: () => 0 });
  cache.set('a', 1, 60);
  cache.set('b', 2, 60);
  cache.get('a');
  cache.set('c', 3, 60);
  assert.strictEqual(cache.get('b'), undefined);
  assert.strictEqual(cache.get('a'), 1);
  assert.strictEqual(cache.get('c'), 3);
});

console.log('all tmdb cache checks passed');
