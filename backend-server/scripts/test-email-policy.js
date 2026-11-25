/* Account emails: stored lowercase, unique regardless of case, ownership tracked. No DB. */
const assert = require('assert');
const { normalizeEmail, emailTakenFilter, profileEmailUpdate } = require('../lib/userHelpers');

assert.strictEqual(normalizeEmail('  Victim@Gmail.COM '), 'victim@gmail.com');
assert.strictEqual(normalizeEmail({ $ne: null }), '[object object]', 'objects never become query operators');

// "Taken" ignores case and excludes the caller.
const f = emailTakenFilter('Victim@Gmail.com', 'me');
assert.ok(f.email.$regex.test('victim@gmail.com'));
assert.ok(f.email.$regex.test('VICTIM@GMAIL.COM'));
assert.ok(!f.email.$regex.test('xvictim@gmail.com'), 'anchored');
assert.deepStrictEqual(f._id, { $ne: 'me' });

// Changing the email stores it lowercase and drops the verified mark; keeping it keeps the mark.
assert.deepStrictEqual(profileEmailUpdate({ email: 'old@x.com', emailVerified: true }, 'New@X.com'), { email: 'new@x.com', emailVerified: false });
assert.deepStrictEqual(profileEmailUpdate({ email: 'old@x.com', emailVerified: true }, 'OLD@x.com '), { email: 'old@x.com' });

console.log('email policy: all passed');
