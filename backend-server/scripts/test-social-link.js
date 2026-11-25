/* Google/Apple sign-in: who gets which account. No DB. */
const assert = require('assert');
const { linkDecision, providerEmailVerified } = require('../lib/socialLink');

const verifiedAcct = { _id: 'a', emailVerified: true };
const unverifiedAcct = { _id: 'b', emailVerified: false };

// Provider id already linked: always that account.
assert.deepStrictEqual(linkDecision({ byProviderId: verifiedAcct, byEmail: null, emailVerified: false }), { action: 'signin', user: verifiedAcct });

// Unverified provider email never links or creates (someone could claim an address they don't own).
assert.strictEqual(linkDecision({ byProviderId: null, byEmail: verifiedAcct, emailVerified: false }).action, 'refuse');
assert.strictEqual(linkDecision({ byProviderId: null, byEmail: null, emailVerified: false }).action, 'refuse');

// Verified provider email + verified account: link.
assert.deepStrictEqual(linkDecision({ byProviderId: null, byEmail: verifiedAcct, emailVerified: true }), { action: 'link', user: verifiedAcct, claim: false });

// Verified provider email + account whose email was never proven: the email owner claims it
// (password reset to random, old sessions revoked), so a pre-registered attacker loses access.
assert.deepStrictEqual(linkDecision({ byProviderId: null, byEmail: unverifiedAcct, emailVerified: true }), { action: 'link', user: unverifiedAcct, claim: true });

// No account: create one, already verified.
assert.deepStrictEqual(linkDecision({ byProviderId: null, byEmail: null, emailVerified: true }), { action: 'create' });

// What counts as verified from each provider.
assert.strictEqual(providerEmailVerified('google', { email_verified: true }), true);
assert.strictEqual(providerEmailVerified('google', { email_verified: 'true' }), false, 'Google sends a boolean');
assert.strictEqual(providerEmailVerified('google', {}), false);
assert.strictEqual(providerEmailVerified('apple', { email_verified: 'true' }), true, 'Apple sends a string');
assert.strictEqual(providerEmailVerified('apple', { email_verified: true }), true);
assert.strictEqual(providerEmailVerified('apple', { email_verified: 'false' }), false);

console.log('social link: all passed');
