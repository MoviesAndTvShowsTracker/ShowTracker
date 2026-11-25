const { normalizeEmail } = require('./userHelpers');

const PROVIDER_FIELDS = ['googleId', 'appleId'];
const RESET_FIELDS = ['resetPasswordToken', 'resetPasswordExpires', 'resetPasswordEmail'];

/**
 * When a verified provider claims an account whose email was never proven, every earlier way in
 * goes: other linked providers and pending reset links (the password is reset by the caller).
 */
function claimUpdates(user, claimingField) {
  // Unconditional: reset fields aren't loaded by default (select: false), so "absent" proves nothing.
  const unset = [...PROVIDER_FIELDS.filter((f) => f !== claimingField), ...RESET_FIELDS];
  return { unset };
}

/** A reset link proves the account's address only if it was sent to that same address. */
function resetProvesEmail(user) {
  return Boolean(user.resetPasswordEmail) && normalizeEmail(user.resetPasswordEmail) === normalizeEmail(user.email);
}

/** A new address is unproven, and reset links sent to the old one stop working. */
function emailChangeUpdates(user, rawEmail) {
  const email = normalizeEmail(rawEmail);
  if (email === normalizeEmail(user.email)) return { set: { email }, unset: [] };
  return { set: { email, emailVerified: false }, unset: [...RESET_FIELDS] };
}

module.exports = { claimUpdates, resetProvesEmail, emailChangeUpdates, RESET_FIELDS };
