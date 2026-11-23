const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const TvShowTracking = new Schema(
  {
    userFrom: { type: Schema.ObjectId, ref: 'User', required: true },
    tvId: { type: String, required: true },
    tvTitle: String,
    tvPosterImage: String,
    tvBackdropImage: String,
    status: {
      type: String,
      enum: ['watching', 'completed', 'paused', 'dropped', 'rewatching'],
      default: 'watching',
    },
    totalEpisodes: { type: Number, default: 0 },
    airedEpisodeCount: { type: Number, default: 0 },
    watchedEpisodeCount: { type: Number, default: 0 },
    nextSeason: Number,
    nextEpisode: Number,
    nextEpisodeName: String,
    lastSeason: Number,
    lastEpisode: Number,
    lastWatchedAt: Date,
    rating: { type: Number, min: 1, max: 10, default: null },
    /** How many times the user has finished the show (first watch + completed rewatches). */
    timesCompleted: { type: Number, default: 0, min: 0 },
    /** Active rewatch session; null when not rewatching. */
    activeRewatchSessionId: { type: Schema.ObjectId, ref: 'TvRewatchSession', default: null },
  },
  { timestamps: true }
);

TvShowTracking.index({ userFrom: 1, tvId: 1 }, { unique: true });
TvShowTracking.index({ userFrom: 1, status: 1, lastWatchedAt: -1 });

module.exports = mongoose.model('TvShowTracking', TvShowTracking);
