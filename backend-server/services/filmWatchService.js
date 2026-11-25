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

/** First watch = the earliest date, whatever order the plays were logged in. */
function rewatchFlags(plays) {
  return [...plays]
    .sort((a, b) => new Date(a.watchedAt || 0) - new Date(b.watchedAt || 0) || String(a._id).localeCompare(String(b._id)))
    .map((p, i) => ({ id: String(p._id), isRewatch: i > 0 }));
}

/** Rewrites isRewatch for every play of a film so it follows the dates. */
async function syncRewatchFlags(userId, movieId) {
  const plays = await Watch.find({ userFrom: userId, movieId: String(movieId) }).select('_id watchedAt isRewatch').lean();
  const current = new Map(plays.map((p) => [String(p._id), Boolean(p.isRewatch)]));
  const ops = rewatchFlags(plays)
    .filter((f) => current.get(f.id) !== f.isRewatch)
    .map((f) => ({ updateOne: { filter: { _id: f.id, userFrom: userId }, update: { $set: { isRewatch: f.isRewatch } } } }));
  if (ops.length) await Watch.bulkWrite(ops);
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
    note: latest?.note || '',
    // Every dated watch, newest first, for the film's diary list.
    plays: sorted.slice(0, 100).map((p) => ({
      id: String(p._id),
      watchedAt: p.watchedAt || null,
      note: p.note || '',
      rating: p.rating ?? null,
      isRewatch: Boolean(p.isRewatch),
    })),
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
  if (fields.note) doc.note = fields.note;

  const play = await Watch.create(doc);
  // A backdated play can become the first watch; flags follow the dates.
  await syncRewatchFlags(userId, movieId);
  const summary = await watchedSummary(userId, movieId);
  const saved = summary.plays.find((p) => p.id === String(play._id));
  if (saved) play.isRewatch = saved.isRewatch;
  return { play, summary };
}

/** Changes the date and/or note of one of the user's plays. Null when it isn't theirs. */
async function updatePlay(userId, playId, { watchedAt, note }) {
  const play = await Watch.findOne({ _id: playId, userFrom: userId });
  if (!play) return null;
  if (watchedAt) play.watchedAt = watchedAt;
  if (note !== undefined) play.note = note;
  await play.save();
  await syncRewatchFlags(userId, play.movieId);
  return { play, summary: await watchedSummary(userId, play.movieId) };
}

/** Delete only the newest play. Older dates stay intact. */
async function removeLatestPlay(userId, movieId) {
  const plays = await listPlaysForMovie(userId, movieId);
  if (!plays.length) {
    return { removed: null, summary: summarizePlays([]) };
  }
  const latest = plays[0];
  await Watch.deleteOne({ _id: latest._id, userFrom: userId });
  await syncRewatchFlags(userId, movieId);
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
  rewatchFlags,
  syncRewatchFlags,
  updatePlay,
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
