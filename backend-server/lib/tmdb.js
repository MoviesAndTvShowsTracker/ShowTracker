const MediaMetaCache = require('../models/mediaMetaCache');

const TMDB_BASE = 'https://api.themoviedb.org/3/';
const REQUEST_DELAY_MS = 200;
const DEFAULT_MAX_FETCHES = 40;

let lastRequestAt = 0;
const memoryCache = new Map();

function apiKey() {
  return process.env.TMDB_API_KEY || '';
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
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
  if (memoryCache.has(endpoint)) return memoryCache.get(endpoint);
  const data = await fetchTmdb(endpoint);
  if (data) memoryCache.set(endpoint, data);
  return data;
}

/** Rate-limited TMDB fetch with no caching. */
async function fetchTmdb(endpoint) {
  const key = apiKey();
  if (!key) return null;

  const gap = Date.now() - lastRequestAt;
  if (gap < REQUEST_DELAY_MS) await sleep(REQUEST_DELAY_MS - gap);

  const url = `${TMDB_BASE}${endpoint.replace(/^\//, '')}?api_key=${key}&language=en-US`;
  lastRequestAt = Date.now();

  try {
    const res = await fetch(url);
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
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

// Air dates change, so seasons expire after 6 hours (memoryCache never does).
const SEASON_TTL_MS = 6 * 60 * 60 * 1000;
const seasonCache = new Map();

async function getExpiring(key) {
  const hit = seasonCache.get(key);
  if (hit && Date.now() - hit.at < SEASON_TTL_MS) return hit.data;
  const data = await fetchTmdb(key);
  if (data) {
    seasonCache.delete(key);
    seasonCache.set(key, { data, at: Date.now() });
    if (seasonCache.size > 500) seasonCache.delete(seasonCache.keys().next().value);
  }
  return data;
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
