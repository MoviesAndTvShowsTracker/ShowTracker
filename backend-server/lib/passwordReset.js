const crypto = require('crypto');

const TOKEN_BYTES = 32;
const RESET_TTL_MS = 60 * 60 * 1000;

const RESET_GENERIC_MESSAGE =
  'If an account exists for that email, we sent a password reset link.';

function generateResetToken() {
  const raw = crypto.randomBytes(TOKEN_BYTES).toString('hex');
  const hash = hashResetToken(raw);
  return {
    raw,
    hash,
    expires: new Date(Date.now() + RESET_TTL_MS),
  };
}

function hashResetToken(raw) {
  return crypto.createHash('sha256').update(raw).digest('hex');
}

function getFrontendUrl() {
  const url = process.env.FRONTEND_URL || 'http://localhost:3000';
  return url.replace(/\/$/, '');
}

function buildResetUrl(rawToken) {
  return `${getFrontendUrl()}/reset-password?token=${encodeURIComponent(rawToken)}`;
}

function setPassword(user, newPassword) {
  return new Promise((resolve, reject) => {
    user.setPassword(newPassword, (err, updated) => {
      if (err) reject(err);
      else resolve(updated);
    });
  });
}

module.exports = {
  RESET_GENERIC_MESSAGE,
  generateResetToken,
  hashResetToken,
  buildResetUrl,
  setPassword,
};
