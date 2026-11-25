/* Diary index payload + ETag revalidation. No DB. */
// Render runs in UTC; Date#toString ordering bugs only show in some zones, so pin it.
process.env.TZ = 'UTC';
const assert = require('assert');
const { sendWithEtag, etagFor } = require('../lib/etag');
const { diaryIndexFromFilms } = require('../services/diaryIndex');

function fakeRes() {
  return {
    statusCode: 200, headers: {}, body: undefined, ended: false,
    setHeader(k, v) { this.headers[k.toLowerCase()] = v; },
    status(c) { this.statusCode = c; return this; },
    json(b) { this.body = b; return this; },
    end() { this.ended = true; return this; },
  };
}

// Same body, same ETag; different body, different ETag.
assert.strictEqual(etagFor({ a: 1 }), etagFor({ a: 1 }));
assert.notStrictEqual(etagFor({ a: 1 }), etagFor({ a: 2 }));
assert.ok(/^W\/"[0-9a-f]+"$/.test(etagFor({ a: 1 })));

// First request: 200 with ETag and must-revalidate caching.
const first = fakeRes();
sendWithEtag({ headers: {} }, first, { a: 1 });
assert.strictEqual(first.statusCode, 200);
assert.deepStrictEqual(first.body, { a: 1 });
assert.strictEqual(first.headers.etag, etagFor({ a: 1 }));
assert.strictEqual(first.headers['cache-control'], 'private, no-cache');

// Revalidation with a matching ETag: 304, no body.
const again = fakeRes();
sendWithEtag({ headers: { 'if-none-match': etagFor({ a: 1 }) } }, again, { a: 1 });
assert.strictEqual(again.statusCode, 304);
assert.ok(again.ended && again.body === undefined);

// Changed data: full 200 again.
const changed = fakeRes();
sendWithEtag({ headers: { 'if-none-match': etagFor({ a: 1 }) } }, changed, { a: 2 });
assert.strictEqual(changed.statusCode, 200);

// Index: [id, plays] per film, watchlist ids, and the newest film rated 4+ stars (10-point ratings halved).
const index = diaryIndexFromFilms(
  [
    { movieId: '1', watchCount: 3, rating: 9, watchedAt: '2026-11-01T00:00:00Z', movieTitle: 'Old love' },
    { movieId: '2', watchCount: 1, rating: 4, watchedAt: '2026-11-20T00:00:00Z', movieTitle: 'New love' },
    { movieId: '3', watchCount: 1, rating: 3.5, watchedAt: '2026-11-24T00:00:00Z', movieTitle: 'Fine' },
    { movieId: '4', watchCount: 2, rating: null, watchedAt: null, movieTitle: 'Unrated' },
  ],
  [{ movieId: '9' }, { movieId: '8' }]
);
assert.deepStrictEqual(index.films, [['1', 3], ['2', 1], ['3', 1], ['4', 2]]);
assert.deepStrictEqual(index.filmWatchlist, ['9', '8']);
assert.deepStrictEqual(index.loved, { id: '2', title: 'New love' });
assert.strictEqual(diaryIndexFromFilms([], []).loved, null);

// MongoDB returns Date objects: the newest by time wins (Fri Nov 20 beats Sun Nov 1), missing dates lose.
const byDate = diaryIndexFromFilms(
  [
    { movieId: 'a', watchCount: 1, rating: 5, watchedAt: new Date('2026-11-01T00:00:00Z'), movieTitle: 'Sunday' },
    { movieId: 'b', watchCount: 1, rating: 5, watchedAt: new Date('2026-11-20T00:00:00Z'), movieTitle: 'Friday' },
    { movieId: 'c', watchCount: 1, rating: 5, watchedAt: null, movieTitle: 'Undated' },
  ],
  []
);
assert.deepStrictEqual(byDate.loved, { id: 'b', title: 'Friday' });

console.log('etag: all passed');
