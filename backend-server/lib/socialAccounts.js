const crypto = require('crypto');
const User = require('../models/user');
const { uniqueUsername, findUserByEmail } = require('./userHelpers');
const { linkDecision } = require('./socialLink');
const { setPassword } = require('./passwordReset');
const { claimUpdates } = require('./accountOwnership');

function registerUser(user, password) {
  return new Promise((resolve, reject) => {
    User.register(user, password, (err, registered) => {
      if (err) reject(err);
      else resolve(registered);
    });
  });
}

/**
 * The account a verified Google/Apple sign-in maps to (see linkDecision).
 * `idField` is 'googleId' or 'appleId'; `names` = { firstName, lastName } to fill blanks.
 */
async function resolveSocialUser({ idField, providerId, email, emailVerified, names, providerLabel }) {
  const byProviderId = await User.findOne({ [idField]: providerId });
  const byEmail = byProviderId || !email ? null : await findUserByEmail(email);
  const decision = linkDecision({ byProviderId, byEmail, emailVerified });

  if (decision.action === 'signin') return decision.user;

  if (decision.action === 'refuse') {
    const err = new Error(
      `Your ${providerLabel} email isn't verified. Verify it with ${providerLabel}, or sign in with your email and password.`
    );
    err.status = 403;
    throw err;
  }

  if (decision.action === 'link') {
    const user = decision.user;
    user[idField] = providerId;
    if (!user.firstName && names.firstName) user.firstName = names.firstName;
    if (!user.lastName && names.lastName) user.lastName = names.lastName;
    if (decision.claim) {
      // The verified email owner takes the account over: whoever set its password before
      // (possibly someone who pre-registered this address) loses it, and their sessions end.
      await setPassword(user, crypto.randomBytes(32).toString('hex'));
      user.passwordChangedAt = new Date();
    }
    user.emailVerified = true;
    await user.save();
    if (decision.claim) {
      // Every earlier way in goes too: another linked provider and any pending reset link.
      const { unset } = claimUpdates(user, idField);
      await User.updateOne({ _id: user._id }, { $unset: Object.fromEntries(unset.map((f) => [f, 1])) });
      unset.forEach((f) => { user[f] = undefined; });
    }
    return user;
  }

  const username = await uniqueUsername(email.split('@')[0] || 'marquee');
  return registerUser(
    new User({
      username,
      email,
      [idField]: providerId,
      firstName: names.firstName || '',
      lastName: names.lastName || '',
      emailVerified: true,
    }),
    crypto.randomBytes(32).toString('hex')
  );
}

module.exports = { resolveSocialUser };
