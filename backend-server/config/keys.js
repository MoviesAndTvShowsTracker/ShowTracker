require('dotenv').config();
const { requireSecret } = require('./secret');

module.exports = {
    mongoURL: process.env.MONGODB_URI || 'mongodb://localhost:27017/userdatabase',
    secret: requireSecret(),
}
