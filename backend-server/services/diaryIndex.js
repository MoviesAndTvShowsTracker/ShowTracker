const Watch = require('../models/watch');
const MovieWatchlist = require('../models/moviewatchlist');
const { libraryFilmsFromPlays } = require('./filmWatchService');

/** Ratings are out of 5; older 10-point values are halved. */
function stars(rating) {
  if (!(rating > 0)) return 0;
  return rating > 5 ? rating / 2 : rating;
}

/**
 * Just what catalogue badges need: [movieId, plays] per film, the watchlist ids, and the
 * newest film rated 4+ stars ("Because you loved"). A few KB instead of every film record.
 */
function diaryIndexFromFilms(films, watchlist) {
  const loved = films
    .filter((f) => stars(f.rating) >= 4)
    .reduce((best, f) => (!best || String(f.watchedAt || '') > String(best.watchedAt || '') ? f : best), null);
  return {
    films: films.map((f) => [String(f.movieId), Math.max(1, f.watchCount || 1)]),
    filmWatchlist: watchlist.map((w) => String(w.movieId)),
    loved: loved ? { id: String(loved.movieId), title: loved.movieTitle || 'a film' } : null,
  };
}

async function buildDiaryIndex(userId) {
  const [plays, watchlist] = await Promise.all([
    Watch.find({ userFrom: userId }).select('movieId movieTitle rating watchedAt isRewatch createdAt updatedAt').lean(),
    MovieWatchlist.find({ userFrom: userId }).select('movieId').sort({ updatedAt: -1, createdAt: -1, _id: -1 }).lean(),
  ]);
  return diaryIndexFromFilms(libraryFilmsFromPlays(plays), watchlist);
}

module.exports = { diaryIndexFromFilms, buildDiaryIndex };
