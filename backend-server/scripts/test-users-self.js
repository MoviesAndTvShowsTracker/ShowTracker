/* A profile is readable only by its owner, and never exposes provider ids or internals. No DB. */
const assert = require('assert');
const { canReadProfile, publicProfile } = require('../lib/userHelpers');

assert.strictEqual(canReadProfile('64b0c0ffee0000000000aaaa', '64b0c0ffee0000000000aaaa'), true);
assert.strictEqual(canReadProfile('64b0c0ffee0000000000aaaa', '64b0c0ffee0000000000bbbb'), false);
assert.strictEqual(canReadProfile({ toString: () => 'x' }, 'x'), true, 'ObjectId vs string');

const shown = publicProfile({
  _id: 'x', email: 'a@b.c', username: 'a', firstName: 'A', lastName: 'B', phonenumber: '555',
  googleId: 'g', appleId: 'p', admin: false, emailVerified: true, passwordChangedAt: new Date(),
  resetPasswordToken: 't', hash: 'h', salt: 's', createdAt: 'c', updatedAt: 'u', __v: 0,
});
assert.deepStrictEqual(Object.keys(shown).sort(),
  ['_id', 'createdAt', 'email', 'emailVerified', 'firstName', 'lastName', 'phonenumber', 'updatedAt', 'username']);

console.log('users self: all passed');
