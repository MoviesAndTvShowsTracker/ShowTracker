const mongoose = require('mongoose');
const Schema = mongoose.Schema;

/** Episode mark belonging to a single rewatch session. */
const TvRewatchEpisode = new Schema(
  {
    userFrom: { type: Schema.ObjectId, ref: 'User', required: true },
    tvId: { type: String, required: true },
    sessionId: { type: Schema.ObjectId, ref: 'TvRewatchSession', required: true },
    seasonNumber: { type: Number, required: true },
    episodeNumber: { type: Number, required: true },
    tmdbEpisodeId: String,
    episodeName: String,
    runtimeMinutes: { type: Number, default: 0 },
    watchedAt: { type: Date, default: Date.now },
    rating: { type: Number, min: 1, max: 10, default: null },
  },
  { timestamps: true }
);

TvRewatchEpisode.index(
  { userFrom: 1, sessionId: 1, seasonNumber: 1, episodeNumber: 1 },
  { unique: true }
);
TvRewatchEpisode.index({ userFrom: 1, watchedAt: -1 });
TvRewatchEpisode.index({ sessionId: 1, seasonNumber: 1, episodeNumber: 1 });

module.exports = mongoose.model('TvRewatchEpisode', TvRewatchEpisode);
