const mongoose = require('mongoose');
const Schema = mongoose.Schema;

const MediaMetaCache = new Schema(
  {
    mediaType: { type: String, enum: ['movie', 'tv'], required: true },
    tmdbId: { type: String, required: true },
    runtime: { type: Number, default: null },
    genres: [{ id: Number, name: String }],
    releaseYear: { type: Number, default: null },
    voteAverage: { type: Number, default: null },
  },
  { timestamps: true }
);

MediaMetaCache.index({ mediaType: 1, tmdbId: 1 }, { unique: true });

module.exports = mongoose.model('MediaMetaCache', MediaMetaCache);
