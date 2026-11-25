/**
 * Who a Google or Apple sign-in becomes.
 * - The provider id already linked: that account.
 * - Otherwise only a verified provider email may link or create (else anyone could claim an address).
 * - Linking to an account whose email was never proven "claims" it: the caller resets its password
 *   and revokes old sessions, so someone who pre-registered the address loses access.
 */
function linkDecision({ byProviderId, byEmail, emailVerified }) {
  if (byProviderId) return { action: 'signin', user: byProviderId };
  if (!emailVerified) return { action: 'refuse' };
  if (byEmail) return { action: 'link', user: byEmail, claim: !byEmail.emailVerified };
  return { action: 'create' };
}

/** Google sends a boolean; Apple sends a string or a boolean. */
function providerEmailVerified(provider, payload) {
  const v = payload && payload.email_verified;
  if (provider === 'google') return v === true;
  return v === true || v === 'true';
}

module.exports = { linkDecision, providerEmailVerified };
