/* Error responses never leak internals; the JWT secret check flags a missing secret. No network. */
const assert = require('assert');
const { errorResponse } = require('../lib/errors');
const { secretStatus } = require('../config/secret');

// 4xx keep their message (the client needs it); 500s are generic.
assert.deepStrictEqual(errorResponse(Object.assign(new Error('Show not found'), { status: 404 })), {
  status: 404, body: { success: false, message: 'Show not found' },
});
const internal = errorResponse(new Error('E11000 duplicate key error collection: users index'));
assert.strictEqual(internal.status, 500);
assert.deepStrictEqual(internal.body, { success: false, message: 'Something went wrong. Try again.' });
assert.strictEqual(errorResponse({ status: 503, message: 'TMDB is not configured' }).body.message, 'Something went wrong. Try again.');

// Secret: set → ok; missing in production → flagged; missing in development → dev fallback allowed.
assert.deepStrictEqual(secretStatus({ JWT_SECRET: 'abc', NODE_ENV: 'production' }), { secret: 'abc', problem: null });
assert.strictEqual(secretStatus({ NODE_ENV: 'production' }).problem, 'JWT_SECRET is not set in production.');
assert.strictEqual(secretStatus({ NODE_ENV: 'development' }).problem, null);
assert.ok(secretStatus({}).secret.length > 0);

console.log('hardening: all passed');
