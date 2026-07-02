const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const TvEpisodeWatch = new Schema(
  {
    userFrom: { type: Schema.ObjectId, ref: 'User', required: true },
    tvId: { type: String, required: true },
    seasonNumber: { type: Number, required: true },
    episodeNumber: { type: Number, required: true },
    tmdbEpisodeId: String,
    episodeName: String,
    runtimeMinutes: { type: Number, default: 0 },
    watchedAt: { type: Date, default: Date.now },
  },
  { timestamps: true }
);

TvEpisodeWatch.index(
  { userFrom: 1, tvId: 1, seasonNumber: 1, episodeNumber: 1 },
  { unique: true }
);
TvEpisodeWatch.index({ userFrom: 1, watchedAt: -1 });

module.exports = mongoose.model('TvEpisodeWatch', TvEpisodeWatch);
