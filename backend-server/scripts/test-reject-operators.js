/* Requests carrying MongoDB operators ($-keys) are refused before any route runs. No DB. */
const assert = require('assert');
const { rejectOperators, hasOperatorKey } = require('../lib/rejectOperators');
const { isRottenTomatoesUrl } = require('../lib/urls');

assert.strictEqual(hasOperatorKey({ movieId: '550' }), false);
assert.strictEqual(hasOperatorKey({ movieId: { $ne: null } }), true);
assert.strictEqual(hasOperatorKey({ episodes: [{ seasonNumber: 1 }, { seasonNumber: { $gt: 0 } }] }), true, 'inside arrays');
assert.strictEqual(hasOperatorKey({ a: { b: { c: { $where: '1' } } } }), true, 'deeply nested');
assert.strictEqual(hasOperatorKey({ note: '$5 off' }), false, 'dollar signs in values are fine');
assert.strictEqual(hasOperatorKey(null), false);

function run(req) {
  let status = 200;
  let passed = false;
  const res = { status(c) { status = c; return this; }, json() { return this; } };
  rejectOperators(req, res, () => { passed = true; });
  return { status, passed };
}
assert.deepStrictEqual(run({ body: { tvId: '1396' }, query: {}, params: {} }), { status: 200, passed: true });
assert.deepStrictEqual(run({ body: { tvId: { $ne: null } }, query: {}, params: {} }), { status: 400, passed: false });
assert.deepStrictEqual(run({ body: {}, query: { tz: { $gt: '' } }, params: {} }), { status: 400, passed: false });

// The ratings scraper only ever fetches Rotten Tomatoes itself.
assert.strictEqual(isRottenTomatoesUrl('https://www.rottentomatoes.com/m/fight_club'), true);
assert.strictEqual(isRottenTomatoesUrl('https://rottentomatoes.com/m/x'), true);
assert.strictEqual(isRottenTomatoesUrl('https://evil.example/rottentomatoes.com'), false);
assert.strictEqual(isRottenTomatoesUrl('https://rottentomatoes.com.evil.example/'), false);
assert.strictEqual(isRottenTomatoesUrl('http://www.rottentomatoes.com/m/x'), false, 'https only');
assert.strictEqual(isRottenTomatoesUrl('N/A'), false);

console.log('reject operators: all passed');
