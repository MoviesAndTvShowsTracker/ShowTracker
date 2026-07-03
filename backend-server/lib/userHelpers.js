const User = require('../models/user');

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

module.exports = { uniqueUsername };
