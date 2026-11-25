/* A claim removes every earlier way in; reset links only prove the address they were sent to. No DB. */
const assert = require('assert');
const { claimUpdates, resetProvesEmail, emailChangeUpdates } = require('../lib/accountOwnership');

// Claiming via Google: the Apple link someone else added and any pending reset link are gone.
const claimed = claimUpdates({ googleId: null, appleId: 'attacker-apple', resetPasswordToken: 'h', resetPasswordExpires: new Date() }, 'googleId');
assert.deepStrictEqual(claimed.unset.sort(), ['appleId', 'resetPasswordEmail', 'resetPasswordExpires', 'resetPasswordToken'].sort());
// Reset fields aren't loaded by default (select: false), so they're always cleared, loaded or not.
assert.ok(claimUpdates({}, 'googleId').unset.includes('resetPasswordToken'));
assert.ok(claimUpdates({}, 'googleId').unset.includes('appleId'), 'the other provider is always cleared');
assert.ok(!claimed.unset.includes('googleId'), 'keeps the claiming provider');
assert.strictEqual(claimUpdates({ appleId: 'mine' }, 'appleId').unset.includes('appleId'), false);

// A reset link proves the address only if it's still the address it was sent to.
assert.strictEqual(resetProvesEmail({ email: 'a@x.com', resetPasswordEmail: 'a@x.com' }), true);
assert.strictEqual(resetProvesEmail({ email: 'victim@x.com', resetPasswordEmail: 'attacker@x.com' }), false);
assert.strictEqual(resetProvesEmail({ email: 'a@x.com' }), false, 'links issued before this field existed prove nothing');

// Changing the email cancels pending reset links and drops the verified mark.
assert.deepStrictEqual(emailChangeUpdates({ email: 'old@x.com' }, 'New@X.com'), {
  set: { email: 'new@x.com', emailVerified: false },
  unset: ['resetPasswordToken', 'resetPasswordExpires', 'resetPasswordEmail'],
});
assert.deepStrictEqual(emailChangeUpdates({ email: 'old@x.com' }, 'OLD@x.com'), { set: { email: 'old@x.com' }, unset: [] });

console.log('claim and reset: all passed');
