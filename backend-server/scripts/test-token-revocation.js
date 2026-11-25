/* Tokens issued before a password change, reset or account claim stop working. No DB. */
const assert = require('assert');
const { tokenRevoked } = require('../authenticate');

const changed = new Date('2026-11-25T12:00:00.700Z');
const sec = (iso) => Math.floor(Date.parse(iso) / 1000);

assert.strictEqual(tokenRevoked(sec('2026-11-01T00:00:00Z'), null), false, 'never changed');
assert.strictEqual(tokenRevoked(sec('2026-11-25T11:59:59Z'), changed), true, 'issued before the change');
assert.strictEqual(tokenRevoked(sec('2026-11-25T12:00:00Z'), changed), false, 'the token issued with the change (same second) works');
assert.strictEqual(tokenRevoked(sec('2026-11-25T12:05:00Z'), changed), false, 'issued after');
assert.strictEqual(tokenRevoked(undefined, changed), true, 'a token without iat is not trusted once a change exists');

console.log('token revocation: all passed');
