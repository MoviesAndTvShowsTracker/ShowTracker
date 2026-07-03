const Watch = require('../models/watch');
const { getMovieMeta, getMovieMetaBatch, getTvMetaBatch } = require('../lib/tmdb');

const MAX_RUNTIME_BACKFILL = 30;
const MAX_TASTE_TV_SHOWS = 60;

function filmRuntimeMinutes(film) {
  return parseInt(film.movieRuntime, 10) || 0;
}

/** Apply runtime from meta map and persist up to maxPerRequest updates. */
async function applyFilmRuntimeBackfill(films, metaMap, maxPerRequest = MAX_RUNTIME_BACKFILL) {
  let backfilled = 0;
  const pending = films.filter((f) => !filmRuntimeMinutes(f));

  for (const film of pending) {
    if (backfilled >= maxPerRequest) break;
    const meta = metaMap.get(String(film.movieId));
    if (!meta?.runtime) continue;
    film.movieRuntime = String(meta.runtime);
    backfilled += 1;
    if (film._id) {
      await Watch.updateOne({ _id: film._id }, { $set: { movieRuntime: film.movieRuntime } });
    }
  }

  return backfilled;
}

async function ensureMovieRuntime(movieId, providedRuntime) {
  const runtime = parseInt(providedRuntime, 10) || 0;
  if (runtime > 0) return runtime;
  const meta = await getMovieMeta(movieId);
  return meta?.runtime || 0;
}

function buildGenreBreakdown(entries, limit = 8) {
  const totals = new Map();
  let grand = 0;

  for (const { genres, weight } of entries) {
    if (!genres?.length || !weight) continue;
    const share = weight / genres.length;
    for (const g of genres) {
      totals.set(g.name, (totals.get(g.name) || 0) + share);
      grand += share;
    }
  }

  return [...totals.entries()]
    .map(([name, value]) => ({
      name,
      value: Math.round(value * 10) / 10,
      pct: grand > 0 ? Math.round((value / grand) * 100) : 0,
    }))
    .sort((a, b) => b.value - a.value)
    .slice(0, limit);
}

function buildDecadeBreakdown(filmsWithMeta) {
  const decades = new Map();

  for (const film of filmsWithMeta) {
    const year = film.releaseYear;
    if (!year || year < 1900) continue;
    const decade = `${Math.floor(year / 10) * 10}s`;
    const bucket = decades.get(decade) || { count: 0, minutes: 0 };
    bucket.count += 1;
    bucket.minutes += film.minutes || 0;
    decades.set(decade, bucket);
  }

  return [...decades.entries()]
    .map(([decade, data]) => ({ decade, ...data }))
    .sort((a, b) => parseInt(a.decade, 10) - parseInt(b.decade, 10));
}

function weightedAverageRating(items) {
  let sum = 0;
  let weight = 0;
  for (const { rating, w } of items) {
    if (!rating || !w) continue;
    sum += rating * w;
    weight += w;
  }
  return weight > 0 ? Math.round((sum / weight) * 10) / 10 : null;
}

function topTvIdsByEpisodes(episodes, limit = MAX_TASTE_TV_SHOWS) {
  const counts = new Map();
  for (const ep of episodes) {
    counts.set(ep.tvId, (counts.get(ep.tvId) || 0) + 1);
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, limit)
    .map(([tvId]) => tvId);
}

function buildTasteProfileFromMaps(films, episodes, filmMetaMap, tvMetaMap, partial = false) {
  const filmsEnriched = films.map((f) => {
    const meta = filmMetaMap.get(String(f.movieId)) || {};
    return {
      movieId: f.movieId,
      minutes: filmRuntimeMinutes(f),
      releaseYear: meta.releaseYear,
      genres: meta.genres || [],
      voteAverage: meta.voteAverage || 0,
    };
  });

  const epCountByShow = new Map();
  for (const ep of episodes) {
    epCountByShow.set(ep.tvId, (epCountByShow.get(ep.tvId) || 0) + 1);
  }

  const tvIds = [...epCountByShow.keys()];

  return {
    available: true,
    partial,
    films: {
      genreByCount: buildGenreBreakdown(
        filmsEnriched.map((f) => ({ genres: f.genres, weight: 1 }))
      ),
      genreByTime: buildGenreBreakdown(
        filmsEnriched.map((f) => ({ genres: f.genres, weight: f.minutes || 1 }))
      ),
      decades: buildDecadeBreakdown(filmsEnriched),
      avgRating: weightedAverageRating(
        filmsEnriched.map((f) => ({ rating: f.voteAverage, w: 1 }))
      ),
    },
    tv: {
      genreByEpisodes: buildGenreBreakdown(
        tvIds.map((tvId) => ({
          genres: tvMetaMap.get(String(tvId))?.genres || [],
          weight: epCountByShow.get(tvId) || 0,
        }))
      ),
      avgRating: weightedAverageRating(
        tvIds.map((tvId) => ({
          rating: tvMetaMap.get(String(tvId))?.voteAverage || 0,
          w: epCountByShow.get(tvId) || 0,
        }))
      ),
    },
  };
}

async function buildTasteProfile(films, episodes, existingFilmMetaMap = null, options = {}) {
  if (!process.env.TMDB_API_KEY) {
    return { available: false };
  }

  const { filmFetchesRemaining = 0 } = options;
  let filmMetaMap = existingFilmMetaMap;
  let filmFetchesLeft = filmFetchesRemaining;

  if (!filmMetaMap) {
    const missingRuntimeIds = films.filter((f) => !filmRuntimeMinutes(f)).map((f) => f.movieId);
    const result = await getMovieMetaBatch(
      films.map((f) => f.movieId),
      { priorityIds: missingRuntimeIds, maxFetches: 25 }
    );
    filmMetaMap = result.map;
    filmFetchesLeft = result.fetchesRemaining;
  }

  const tasteTvIds = topTvIdsByEpisodes(episodes);
  const { map: tvMetaMap, fetchesRemaining: tvFetchesLeft } = await getTvMetaBatch(tasteTvIds, {
    maxFetches: 25,
  });

  const partial = filmFetchesLeft > 0 || tvFetchesLeft > 0;

  return buildTasteProfileFromMaps(films, episodes, filmMetaMap, tvMetaMap, partial);
}

module.exports = {
  applyFilmRuntimeBackfill,
  ensureMovieRuntime,
  filmRuntimeMinutes,
  buildTasteProfile,
  MAX_RUNTIME_BACKFILL,
};
