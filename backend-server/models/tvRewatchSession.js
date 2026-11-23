const mongoose = require('mongoose');
const Schema = mongoose.Schema;

/**
 * One rewatch run through a show. Canonical TvEpisodeWatch rows stay untouched.
 */
const TvRewatchSession = new Schema(
  {
    userFrom: { type: Schema.ObjectId, ref: 'User', required: true },
    tvId: { type: String, required: true },
    /** 1-based ordinal among this user's sessions for the show. */
    sessionNumber: { type: Number, required: true, min: 1 },
    status: {
      type: String,
      enum: ['active', 'completed', 'cancelled'],
      default: 'active',
    },
    startedAt: { type: Date, default: Date.now },
    completedAt: { type: Date, default: null },
    cancelledAt: { type: Date, default: null },
    watchedEpisodeCount: { type: Number, default: 0 },
    totalEpisodes: { type: Number, default: 0 },
    airedEpisodeCount: { type: Number, default: 0 },
    nextSeason: Number,
    nextEpisode: Number,
    nextEpisodeName: String,
    lastSeason: Number,
    lastEpisode: Number,
    lastWatchedAt: Date,
  },
  { timestamps: true }
);

TvRewatchSession.index({ userFrom: 1, tvId: 1, sessionNumber: 1 }, { unique: true });
TvRewatchSession.index(
  { userFrom: 1, tvId: 1, status: 1 },
  { unique: true, partialFilterExpression: { status: 'active' } }
);

module.exports = mongoose.model('TvRewatchSession', TvRewatchSession);
