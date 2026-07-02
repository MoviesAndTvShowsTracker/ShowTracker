require('dotenv').config();

module.exports = {
    mongoURL: process.env.MONGODB_URI || 'mongodb://localhost:27017/userdatabase',
    secret: process.env.JWT_SECRET || '51811-42966-52626-65419'
}