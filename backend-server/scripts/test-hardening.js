/* Error responses never leak internals; the JWT secret check flags a missing secret. No network. */
const assert = require('assert');
const { errorResponse } = require('../lib/errors');
const { secretStatus, requireSecret } = require('../config/secret');
const { securityHeaders } = require('../lib/securityHeaders');

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

// Production refuses to start without a secret; development keeps its local fallback.
assert.throws(() => requireSecret({ NODE_ENV: 'production' }), /JWT_SECRET/);
assert.strictEqual(requireSecret({ NODE_ENV: 'production', JWT_SECRET: 'abc' }), 'abc');
assert.ok(requireSecret({ NODE_ENV: 'development' }).length > 0);

// Every response carries the baseline headers, including HSTS.
const headers = {};
securityHeaders({}, { setHeader: (k, v) => { headers[k.toLowerCase()] = v; } }, () => {});
assert.strictEqual(headers['strict-transport-security'], 'max-age=31536000; includeSubDomains');
assert.strictEqual(headers['x-content-type-options'], 'nosniff');
assert.strictEqual(headers['x-frame-options'], 'DENY');
assert.strictEqual(headers['referrer-policy'], 'no-referrer');

console.log('hardening: all passed');
