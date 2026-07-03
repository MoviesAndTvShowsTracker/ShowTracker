const crypto = require('crypto');
const { OAuth2Client } = require('google-auth-library');
const User = require('../models/user');

const { uniqueUsername, normalizeEmail, findUserByEmail } = require('./userHelpers');

function registerUser(user, password) {
  return new Promise((resolve, reject) => {
    User.register(user, password, (err, registered) => {
      if (err) reject(err);
      else resolve(registered);
    });
  });
}

async function verifyGoogleIdToken(idToken) {
  const clientId = process.env.GOOGLE_CLIENT_ID;
  if (!clientId) {
    const err = new Error('Google sign-in is not configured on the server.');
    err.status = 503;
    throw err;
  }

  const client = new OAuth2Client(clientId);
  const ticket = await client.verifyIdToken({ idToken, audience: clientId });
  return ticket.getPayload();
}

async function findOrCreateGoogleUser(payload) {
  const googleId = payload.sub;
  const email = normalizeEmail(payload.email);
  if (!googleId || !email) {
    const err = new Error('Google account must include an email address.');
    err.status = 400;
    throw err;
  }

  let user = await User.findOne({ googleId });
  if (!user) {
    user = await findUserByEmail(email);
  }

  if (user) {
    if (!user.googleId) {
      user.googleId = googleId;
      if (!user.firstName && payload.given_name) user.firstName = payload.given_name;
      if (!user.lastName && payload.family_name) user.lastName = payload.family_name;
      await user.save();
    }
    return user;
  }

  const username = await uniqueUsername(email.split('@')[0]);
  return registerUser(
    new User({
      username,
      email,
      googleId,
      firstName: payload.given_name || '',
      lastName: payload.family_name || '',
    }),
    crypto.randomBytes(32).toString('hex')
  );
}

module.exports = { verifyGoogleIdToken, findOrCreateGoogleUser };
