const Favorite = require('../models/favorite');
const FavoriteTv = require('../models/favoritefortv');
const MovieWatchlist = require('../models/moviewatchlist');
const TvWatchlist = require('../models/tvwatchlist');
const TvEpisodeWatch = require('../models/tvEpisodeWatch');
const { resolveShowTracking, findTracking, TRACKED_STATUSES } = require('./tvTrackingService');
const { getRewatchState } = require('./tvRewatchService');
const { watchedSummary } = require('./filmWatchService');

/**
 * Everything a detail page needs to know about the signed-in user and one title, in one
 * response. Each lookup matches what the older one-question endpoints return.
 */

const tvLookups = {
  favorited: async (userId, tvId) => Boolean(await FavoriteTv.exists({ userFrom: userId, tvId })),
  // A show in the library (watching, paused, finished, rewatching) is never "on the watchlist".
  watchlisted: async (userId, tvId) => {
    const tracked = await findTracking(userId, tvId);
    if (tracked && TRACKED_STATUSES.includes(tracked.status)) return false;
    return Boolean(await TvWatchlist.exists({ userFrom: userId, tvId }));
  },
  tracking: (userId, tvId) => resolveShowTracking(userId, tvId),
  episodes: (userId, tvId) =>
    TvEpisodeWatch.find({ userFrom: userId, tvId }).sort({ seasonNumber: 1, episodeNumber: 1 }).lean(),
  rewatch: (userId, tvId) => getRewatchState(userId, tvId),
};

const movieLookups = {
  favorited: async (userId, movieId) => Boolean(await Favorite.exists({ userFrom: userId, movieId })),
  watchlisted: async (userId, movieId) => Boolean(await MovieWatchlist.exists({ userFrom: userId, movieId })),
  watched: (userId, movieId) => watchedSummary(userId, movieId),
};

async function buildTvState(userId, tvId, lookups = tvLookups) {
  const [favorited, watchlisted, tracking, episodes, rewatch] = await Promise.all([
    lookups.favorited(userId, tvId),
    lookups.watchlisted(userId, tvId),
    lookups.tracking(userId, tvId),
    lookups.episodes(userId, tvId),
    lookups.rewatch(userId, tvId),
  ]);
  return { favorited, watchlisted, tracking, episodes, rewatch };
}

async function buildMovieState(userId, movieId, lookups = movieLookups) {
  const [favorited, watchlisted, watched] = await Promise.all([
    lookups.favorited(userId, movieId),
    lookups.watchlisted(userId, movieId),
    lookups.watched(userId, movieId),
  ]);
  return { favorited, watchlisted, watched };
}

module.exports = { buildTvState, buildMovieState };
