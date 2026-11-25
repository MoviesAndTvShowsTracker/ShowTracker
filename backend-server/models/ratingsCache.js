const mongoose = require('mongoose');

/** Persisted ratings per title; MongoDB deletes each row when `expiresAt` passes. */
const RatingsCache = new mongoose.Schema({
  key: { type: String, required: true, unique: true },
  payload: { type: mongoose.Schema.Types.Mixed, required: true },
  expiresAt: { type: Date, required: true },
});

RatingsCache.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

module.exports = mongoose.model('RatingsCache', RatingsCache);
