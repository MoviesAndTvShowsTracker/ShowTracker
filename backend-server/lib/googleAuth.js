const { OAuth2Client } = require('google-auth-library');

const { normalizeEmail } = require('./userHelpers');
const { resolveSocialUser } = require('./socialAccounts');
const { providerEmailVerified } = require('./socialLink');

function googleAudiences() {
  return [...new Set(
    [process.env.GOOGLE_CLIENT_ID, process.env.GOOGLE_IOS_CLIENT_ID]
      .flatMap((value) => (value || '').split(','))
      .map((value) => value.trim())
      .filter(Boolean)
  )];
}

async function verifyGoogleIdToken(idToken) {
  const audiences = googleAudiences();
  if (!audiences.length) {
    const err = new Error('Google sign-in is not configured on the server.');
    err.status = 503;
    throw err;
  }

  const client = new OAuth2Client();
  let lastError;
  for (const audience of audiences) {
    try {
      const ticket = await client.verifyIdToken({ idToken, audience });
      return ticket.getPayload();
    } catch (err) {
      lastError = err;
    }
  }

  const err = new Error('Google sign-in could not be verified.');
  err.status = 401;
  err.cause = lastError;
  throw err;
}

async function findOrCreateGoogleUser(payload) {
  const googleId = payload.sub;
  const email = normalizeEmail(payload.email);
  if (!googleId || !email) {
    const err = new Error('Google account must include an email address.');
    err.status = 400;
    throw err;
  }
  return resolveSocialUser({
    idField: 'googleId',
    providerId: googleId,
    email,
    emailVerified: providerEmailVerified('google', payload),
    names: { firstName: payload.given_name || '', lastName: payload.family_name || '' },
    providerLabel: 'Google',
  });
}

module.exports = { verifyGoogleIdToken, findOrCreateGoogleUser };
