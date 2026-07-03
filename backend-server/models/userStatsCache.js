const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const UserStatsCache = new Schema(
  {
    userFrom: { type: Schema.ObjectId, ref: 'User', required: true, unique: true },
    stats: { type: Schema.Types.Mixed, required: true },
    builtAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

module.exports = mongoose.model('UserStatsCache', UserStatsCache);
