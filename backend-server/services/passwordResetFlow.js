const { normalizeEmail, findUserByEmail } = require('../lib/userHelpers');
const { RESET_GENERIC_MESSAGE, generateResetToken, buildResetUrl } = require('../lib/passwordReset');

/** The one answer for every forgot-password request, so it never reveals whether an account exists. */
const RESET_RESPONSE = Object.freeze({ success: true, message: RESET_GENERIC_MESSAGE });

/** Stores a fresh reset token and emails the link; clears the token if the email can't be sent. */
async function issueReset(user) {
  const { sendPasswordResetEmail } = require('../lib/mail');
  const { raw, hash, expires } = generateResetToken();
  user.resetPasswordToken = hash;
  user.resetPasswordExpires = expires;
  user.resetPasswordEmail = user.email;
  await user.save();
  try {
    await sendPasswordResetEmail({ to: user.email, resetUrl: buildResetUrl(raw) });
  } catch (err) {
    user.resetPasswordToken = undefined;
    user.resetPasswordExpires = undefined;
    user.resetPasswordEmail = undefined;
    await user.save();
    throw err;
  }
}

/**
 * Answers immediately with the same body for any address; the lookup and email happen afterwards,
 * so neither the response nor its timing says whether the account exists.
 */
async function requestPasswordReset(rawEmail, deps = {}) {
  const { findUser = findUserByEmail, issue = deps.issueReset || issueReset, log = console.error } = deps;
  const email = normalizeEmail(rawEmail);
  if (!email) {
    const err = new Error('Email is required.');
    err.status = 400;
    throw err;
  }
  setImmediate(async () => {
    try {
      const user = await findUser(email);
      if (user) await issue(user);
    } catch (err) {
      log(`[forgot-password] ${err.message}`);
    }
  });
  return { ...RESET_RESPONSE };
}

module.exports = { requestPasswordReset, RESET_RESPONSE };
