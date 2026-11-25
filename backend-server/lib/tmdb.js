const MediaMetaCache = require('../models/mediaMetaCache');

const TMDB_BASE = 'https://api.themoviedb.org/3/';
const DEFAULT_MAX_FETCHES = 40;

const { tmdbClient } = require('./tmdbClient');

const DAY_SECONDS = 24 * 60 * 60;
// Air dates change, so seasons and show detail expire after 6 hours.
const SIX_HOURS_SECONDS = 6 * 60 * 60;

function apiKey() {
  return process.env.TMDB_API_KEY || '';
}

function rowToMovieMeta(row) {
  if (!row) return null;
  return {
    runtime: row.runtime || 0,
    genres: row.genres || [],
    releaseYear: row.releaseYear,
    voteAverage: row.voteAverage || 0,
  };
}

function rowToTvMeta(row) {
  if (!row) return null;
  return {
    genres: row.genres || [],
    releaseYear: row.releaseYear,
    voteAverage: row.voteAverage || 0,
  };
}

async function tmdbRequest(endpoint) {
  return fetchTmdb(endpoint, DAY_SECONDS);
}

/** TMDB JSON through the shared client (cache, coalescing, timeout, concurrency cap); null on failure. */
async function fetchTmdb(endpoint, ttlSeconds = DAY_SECONDS) {
  const key = apiKey();
  if (!key) return null;
  const path = endpoint.replace(/^\//, '');
  const url = `${TMDB_BASE}${path}?api_key=${key}&language=en-US`;
  return tmdbClient().getJson(url, { cacheKey: `lib:${path}`, ttlSeconds });
}

function normalizeMovieMeta(data) {
  if (!data) return null;
  return {
    runtime: data.runtime || 0,
    genres: (data.genres || []).map((g) => ({ id: g.id, name: g.name })),
    releaseYear: data.release_date ? parseInt(data.release_date.slice(0, 4), 10) : null,
    voteAverage: data.vote_average || 0,
  };
}

function normalizeTvMeta(data) {
  if (!data) return null;
  const year = data.first_air_date ? parseInt(data.first_air_date.slice(0, 4), 10) : null;
  return {
    genres: (data.genres || []).map((g) => ({ id: g.id, name: g.name })),
    releaseYear: year,
    voteAverage: data.vote_average || 0,
  };
}

async function loadCachedMetaBatch(mediaType, ids) {
  const unique = [...new Set(ids.map(String))];
  const map = new Map();
  if (!unique.length) return map;

  const rows = await MediaMetaCache.find({
    mediaType,
    tmdbId: { $in: unique },
  }).lean();

  for (const row of rows) {
    map.set(
      row.tmdbId,
      mediaType === 'movie' ? rowToMovieMeta(row) : rowToTvMeta(row)
    );
  }
  return map;
}

async function saveCachedMeta(mediaType, tmdbId, meta) {
  if (!meta) return;
  await MediaMetaCache.findOneAndUpdate(
    { mediaType, tmdbId: String(tmdbId) },
    {
      mediaType,
      tmdbId: String(tmdbId),
      runtime: meta.runtime ?? null,
      genres: meta.genres || [],
      releaseYear: meta.releaseYear ?? null,
      voteAverage: meta.voteAverage ?? null,
    },
    { upsert: true, new: true }
  );
}

async function fetchAndCacheMovie(id) {
  const data = await tmdbRequest(`movie/${id}`);
  const meta = normalizeMovieMeta(data);
  if (meta) await saveCachedMeta('movie', id, meta);
  return meta;
}

async function fetchAndCacheTv(id) {
  const data = await tmdbRequest(`tv/${id}`);
  const meta = normalizeTvMeta(data);
  if (meta) await saveCachedMeta('tv', id, meta);
  return meta;
}

async function getMovieMeta(movieId) {
  const id = String(movieId);
  const batch = await loadCachedMetaBatch('movie', [id]);
  if (batch.has(id)) return batch.get(id);
  return fetchAndCacheMovie(id);
}

async function getTvMeta(tvId) {
  const id = String(tvId);
  const batch = await loadCachedMetaBatch('tv', [id]);
  if (batch.has(id)) return batch.get(id);
  return fetchAndCacheTv(id);
}

/**
 * Load metadata for many IDs: one DB query, then capped TMDB fetches for cache misses.
 */
async function getMovieMetaBatch(movieIds, { maxFetches = DEFAULT_MAX_FETCHES, priorityIds = [] } = {}) {
  const unique = [...new Set(movieIds.map(String))];
  const map = await loadCachedMetaBatch('movie', unique);

  const priority = [...new Set(priorityIds.map(String))];
  const uncached = [
    ...priority.filter((id) => unique.includes(id) && !map.has(id)),
    ...unique.filter((id) => !map.has(id) && !priority.includes(id)),
  ];

  let fetches = 0;
  for (const id of uncached) {
    if (fetches >= maxFetches) break;
    const meta = await fetchAndCacheMovie(id);
    if (meta) map.set(id, meta);
    fetches += 1;
  }

  return { map, fetchesRemaining: Math.max(0, uncached.length - fetches) };
}

async function getTvMetaBatch(tvIds, { maxFetches = DEFAULT_MAX_FETCHES, priorityIds = [] } = {}) {
  const unique = [...new Set(tvIds.map(String))];
  const map = await loadCachedMetaBatch('tv', unique);

  const priority = [...new Set(priorityIds.map(String))];
  const uncached = [
    ...priority.filter((id) => unique.includes(id) && !map.has(id)),
    ...unique.filter((id) => !map.has(id) && !priority.includes(id)),
  ];

  let fetches = 0;
  for (const id of uncached) {
    if (fetches >= maxFetches) break;
    const meta = await fetchAndCacheTv(id);
    if (meta) map.set(id, meta);
    fetches += 1;
  }

  return { map, fetchesRemaining: Math.max(0, uncached.length - fetches) };
}

async function getExpiring(key) {
  return fetchTmdb(key, SIX_HOURS_SECONDS);
}

async function getTvSeason(tvId, season) {
  return getExpiring(`tv/${tvId}/season/${season}`);
}

/** Full show detail (seasons, last aired episode). Expires like seasons, so new seasons appear. */
async function getTvShow(tvId) {
  return getExpiring(`tv/${tvId}`);
}

module.exports = {
  getTvSeason,
  getTvShow,
  getMovieMeta,
  getTvMeta,
  getMovieMetaBatch,
  getTvMetaBatch,
  DEFAULT_MAX_FETCHES,
};
