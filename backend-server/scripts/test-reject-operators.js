/* Requests carrying MongoDB operators ($-keys) are refused before any route runs. No DB. */
const assert = require('assert');
const { rejectOperators, hasOperatorKey } = require('../lib/rejectOperators');

assert.strictEqual(hasOperatorKey({ movieId: '550' }), false);
assert.strictEqual(hasOperatorKey({ movieId: { $ne: null } }), true);
assert.strictEqual(hasOperatorKey({ episodes: [{ seasonNumber: 1 }, { seasonNumber: { $gt: 0 } }] }), true, 'inside arrays');
assert.strictEqual(hasOperatorKey({ a: { b: { c: { $where: '1' } } } }), true, 'deeply nested');
assert.strictEqual(hasOperatorKey({ note: '$5 off' }), false, 'dollar signs in values are fine');
assert.strictEqual(hasOperatorKey(null), false);
let deep = { x: 1 };
for (let i = 0; i < 30; i += 1) deep = { a: deep };
assert.strictEqual(hasOperatorKey(deep), true, 'implausibly deep input is refused');

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


console.log('reject operators: all passed');
