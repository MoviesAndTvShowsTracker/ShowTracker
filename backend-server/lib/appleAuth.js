const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const User = require('../models/user');
const { normalizeEmail } = require('./userHelpers');
const { resolveSocialUser } = require('./socialAccounts');
const { providerEmailVerified } = require('./socialLink');

const APPLE_ISSUER = 'https://appleid.apple.com';
const APPLE_KEYS_URL = 'https://appleid.apple.com/auth/keys';

/** @type {{ keys: object[], fetchedAt: number } | null} */
let appleKeysCache = null;
const KEYS_TTL_MS = 60 * 60 * 1000;

function appleClientId() {
  return (process.env.APPLE_CLIENT_ID || 'com.jimil.marquee').trim();
}

async function fetchAppleKeys() {
  if (appleKeysCache && Date.now() - appleKeysCache.fetchedAt < KEYS_TTL_MS) {
    return appleKeysCache.keys;
  }
  const res = await fetch(APPLE_KEYS_URL);
  if (!res.ok) {
    const err = new Error('Could not load Apple signing keys.');
    err.status = 503;
    throw err;
  }
  const body = await res.json();
  appleKeysCache = { keys: body.keys || [], fetchedAt: Date.now() };
  return appleKeysCache.keys;
}

function jwkToPem(jwk) {
  // Minimal JWK (RSA) → PEM via Node crypto KeyObject
  const keyObject = crypto.createPublicKey({ key: jwk, format: 'jwk' });
  return keyObject.export({ type: 'spki', format: 'pem' });
}

function sha256Hex(value) {
  return crypto.createHash('sha256').update(value, 'utf8').digest('hex');
}

/**
 * @param {string} identityToken
 * @param {string} rawNonce
 */
async function verifyAppleIdentityToken(identityToken, rawNonce) {
  if (!identityToken || typeof identityToken !== 'string') {
    const err = new Error('Missing Apple identity token.');
    err.status = 400;
    throw err;
  }
  if (!rawNonce || typeof rawNonce !== 'string' || rawNonce.length < 16) {
    const err = new Error('Missing Apple sign-in nonce.');
    err.status = 400;
    throw err;
  }

  const audience = appleClientId();
  if (!audience) {
    const err = new Error('Apple sign-in is not configured on the server.');
    err.status = 503;
    throw err;
  }

  const decoded = jwt.decode(identityToken, { complete: true });
  if (!decoded?.header?.kid) {
    const err = new Error('Apple sign-in token is malformed.');
    err.status = 401;
    throw err;
  }

  const keys = await fetchAppleKeys();
  const jwk = keys.find((k) => k.kid === decoded.header.kid);
  if (!jwk) {
    // Force refresh once for unknown kid
    appleKeysCache = null;
    const fresh = await fetchAppleKeys();
    const retry = fresh.find((k) => k.kid === decoded.header.kid);
    if (!retry) {
      const err = new Error('Apple sign-in could not be verified.');
      err.status = 401;
      throw err;
    }
    return verifyWithKey(identityToken, rawNonce, audience, retry);
  }

  return verifyWithKey(identityToken, rawNonce, audience, jwk);
}

function verifyWithKey(identityToken, rawNonce, audience, jwk) {
  let payload;
  try {
    payload = jwt.verify(identityToken, jwkToPem(jwk), {
      algorithms: ['RS256'],
      issuer: APPLE_ISSUER,
      audience,
    });
  } catch (cause) {
    const err = new Error('Apple sign-in could not be verified.');
    err.status = 401;
    err.cause = cause;
    throw err;
  }

  const expected = sha256Hex(rawNonce);
  const actual = String(payload.nonce || '');
  if (!actual || actual.length !== expected.length
      || !crypto.timingSafeEqual(Buffer.from(actual), Buffer.from(expected))) {
    const err = new Error('Apple sign-in nonce mismatch.');
    err.status = 401;
    throw err;
  }

  if (!payload.sub) {
    const err = new Error('Apple account is missing a user id.');
    err.status = 400;
    throw err;
  }

  return payload;
}

/**
 * @param {object} payload
 * @param {{ givenName?: string, familyName?: string } | null} fullName
 */
async function findOrCreateAppleUser(payload, fullName = null) {
  const appleId = payload.sub;
  const email = payload.email ? normalizeEmail(payload.email) : null;
  const byAppleId = await User.findOne({ appleId });
  if (!byAppleId && !email) {
    const err = new Error(
      'Apple did not share an email for this account. In Settings → Apple Account → Sign in with Apple, stop using Marquee, then try again and share your email.'
    );
    err.status = 400;
    throw err;
  }
  return resolveSocialUser({
    idField: 'appleId',
    providerId: appleId,
    email,
    emailVerified: providerEmailVerified('apple', payload),
    names: { firstName: fullName?.givenName || '', lastName: fullName?.familyName || '' },
    providerLabel: 'Apple',
  });
}

module.exports = {
  verifyAppleIdentityToken,
  findOrCreateAppleUser,
};
