require('dotenv').config();
const { secretStatus } = require('./secret');

const jwt = secretStatus();
if (jwt.problem) {
  // Loud, not fatal yet: confirm JWT_SECRET is set on Render, then this can throw.
  console.error(`[security] ${jwt.problem} Tokens are signed with the development fallback.`);
}

module.exports = {
    mongoURL: process.env.MONGODB_URI || 'mongodb://localhost:27017/userdatabase',
    secret: jwt.secret,
}
