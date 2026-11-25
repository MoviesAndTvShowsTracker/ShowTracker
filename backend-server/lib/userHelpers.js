const User = require('../models/user');

function normalizeEmail(raw) {
  return String(raw || '').trim().toLowerCase();
}

function escapeRegex(str) {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

async function findUserByEmail(rawEmail) {
  const trimmed = String(rawEmail || '').trim();
  if (!trimmed) return null;
  return User.findOne({
    email: { $regex: new RegExp(`^${escapeRegex(trimmed)}$`, 'i') },
  });
}

async function uniqueUsername(base) {
  const cleaned = String(base || 'user')
    .toLowerCase()
    .replace(/[^a-z0-9_]/g, '')
    .slice(0, 20);
  const root = cleaned || 'user';
  let candidate = root;
  let n = 0;
  while (await User.findOne({ username: candidate })) {
    n += 1;
    candidate = `${root}${n}`;
  }
  return candidate;
}

/** Another account using this email, ignoring case. */
function emailTakenFilter(rawEmail, userId) {
  const email = normalizeEmail(rawEmail);
  return { email: { $regex: new RegExp(`^${escapeRegex(email)}$`, 'i') }, _id: { $ne: userId } };
}

/** Fields to save when a profile edit sets `rawEmail`; a different address is no longer proven. */
function profileEmailUpdate(user, rawEmail) {
  const email = normalizeEmail(rawEmail);
  if (email === normalizeEmail(user.email)) return { email };
  return { email, emailVerified: false };
}

/** Only the account owner may read their profile. */
function canReadProfile(requesterId, targetId) {
  return String(requesterId) === String(targetId);
}

const PROFILE_FIELDS = ['_id', 'email', 'username', 'firstName', 'lastName', 'phonenumber', 'emailVerified', 'createdAt', 'updatedAt'];

/** The profile fields clients use; never provider ids, flags or password internals. */
function publicProfile(user) {
  const src = user && typeof user.toObject === 'function' ? user.toObject() : user || {};
  return Object.fromEntries(PROFILE_FIELDS.filter((k) => src[k] !== undefined).map((k) => [k, src[k]]));
}

module.exports = {
  uniqueUsername,
  normalizeEmail,
  findUserByEmail,
  emailTakenFilter,
  profileEmailUpdate,
  canReadProfile,
  publicProfile,
};
