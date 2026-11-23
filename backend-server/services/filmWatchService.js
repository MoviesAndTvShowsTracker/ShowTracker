const Watch = require('../models/watch');
const { dedupeFilms } = require('./filmDedupe');

/** Newest play first. */
function sortPlaysNewestFirst(plays) {
  return [...plays].sort((a, b) => {
    const aAt = new Date(a.watchedAt || a.updatedAt || a.createdAt || 0).getTime();
    const bAt = new Date(b.watchedAt || b.updatedAt || b.createdAt || 0).getTime();
    if (bAt !== aAt) return bAt - aAt;
    return String(b._id).localeCompare(String(a._id));
  });
}

async function listPlaysForMovie(userId, movieId) {
  const plays = await Watch.find({ userFrom: userId, movieId: String(movieId) }).lean();
  return sortPlaysNewestFirst(plays);
}

function summarizePlays(plays) {
  const sorted = sortPlaysNewestFirst(plays);
  const latest = sorted[0] || null;
  return {
    watched: sorted.length > 0,
    watchCount: sorted.length,
    watchedAt: latest?.watchedAt || null,
    rating: latest?.rating ?? null,
    isRewatch: sorted.length > 1,
    latestPlayId: latest?._id ? String(latest._id) : null,
  };
}

/**
 * Library list: one row per movieId with aggregate fields.
 * Newest play wins for poster/title/rating/watchedAt; watchCount is total plays.
 */
function libraryFilmsFromPlays(plays) {
  const byId = new Map();
  for (const play of sortPlaysNewestFirst(plays)) {
    const id = String(play.movieId);
    const prev = byId.get(id);
    if (!prev) {
      byId.set(id, {
        ...play,
        watchCount: 1,
        isRewatch: Boolean(play.isRewatch),
      });
      continue;
    }
    prev.watchCount += 1;
    if (play.isRewatch) prev.isRewatch = true;
  }
  return [...byId.values()];
}

async function watchedSummary(userId, movieId) {
  const plays = await listPlaysForMovie(userId, movieId);
  return summarizePlays(plays);
}

/**
 * Append a play. Never mutates an earlier play's watchedAt.
 * First play: isRewatch=false. Later plays: isRewatch=true.
 */
async function addFilmPlay(userId, fields) {
  const movieId = String(fields.movieId);
  const existingCount = await Watch.countDocuments({ userFrom: userId, movieId });
  const watchedAt = fields.watchedAt ? new Date(fields.watchedAt) : new Date();
  const doc = {
    userFrom: userId,
    movieId,
    movieTitle: fields.movieTitle,
    movieImage: fields.movieImage,
    moviePosterImage: fields.moviePosterImage,
    movieRuntime: fields.movieRuntime,
    watchedAt,
    isRewatch: existingCount > 0,
  };
  if (fields.rating !== undefined) doc.rating = fields.rating;

  const play = await Watch.create(doc);
  const summary = await watchedSummary(userId, movieId);
  return { play, summary };
}

/** Delete only the newest play. Older dates stay intact. */
async function removeLatestPlay(userId, movieId) {
  const plays = await listPlaysForMovie(userId, movieId);
  if (!plays.length) {
    return { removed: null, summary: summarizePlays([]) };
  }
  const latest = plays[0];
  await Watch.deleteOne({ _id: latest._id, userFrom: userId });
  const remaining = plays.slice(1);
  return { removed: latest, summary: summarizePlays(remaining) };
}

/** Wipe every play for this film (clear from watched library). */
async function removeAllPlays(userId, movieId) {
  const result = await Watch.deleteMany({ userFrom: userId, movieId: String(movieId) });
  return {
    deletedCount: result.deletedCount || 0,
    summary: summarizePlays([]),
  };
}

/** Rate the newest play only (shelf rating). */
async function rateLatestPlay(userId, movieId, rating) {
  const plays = await listPlaysForMovie(userId, movieId);
  if (!plays.length) return null;
  const latest = plays[0];
  const updated = await Watch.findOneAndUpdate(
    { _id: latest._id, userFrom: userId },
    { $set: { rating } },
    { new: true }
  );
  return updated;
}

/** Prefer newest non-null rating when collapsing watches for favorites. */
function ratingByMovieId(plays) {
  const map = new Map();
  for (const play of sortPlaysNewestFirst(plays)) {
    const id = String(play.movieId);
    if (map.has(id)) continue;
    map.set(id, play.rating ?? null);
  }
  return map;
}

module.exports = {
  sortPlaysNewestFirst,
  listPlaysForMovie,
  summarizePlays,
  libraryFilmsFromPlays,
  watchedSummary,
  addFilmPlay,
  removeLatestPlay,
  removeAllPlays,
  rateLatestPlay,
  ratingByMovieId,
  dedupeFilms,
};
