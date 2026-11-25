const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const UserStatsCache = new Schema(
  {
    userFrom: { type: Schema.ObjectId, ref: 'User', required: true, unique: true },
    stats: { type: Schema.Types.Mixed, required: true },
    builtAt: { type: Date, default: Date.now },
    // Set by writes; stale when it is later than builtAt (the build's start).
    staleAt: { type: Date, default: null },
  },
  { timestamps: true }
);

module.exports = mongoose.model('UserStatsCache', UserStatsCache);
