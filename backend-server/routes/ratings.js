const express = require('express');

const router = express.Router();

const TMDB_BASE = 'https://api.themoviedb.org/3/';
const OMDB_BASE = 'https://www.omdbapi.com/';
const CACHE_TTL_MS = 24 * 60 * 60 * 1000;
const RatingsCache = require('../models/ratingsCache');
const { createRatingsStore } = require('../services/ratingsStore');

function parseOmdbRatings(body) {
  const out = {
    imdb: null,
    rottenTomatoes: null,
    metacritic: null,
  };
  if (!body || body.Response === 'False') return out;

  if (body.imdbRating && body.imdbRating !== 'N/A') {
    const value = Number.parseFloat(body.imdbRating);
    if (!Number.isNaN(value)) {
      out.imdb = {
        value,
        scale: 10,
        votes: body.imdbVotes && body.imdbVotes !== 'N/A' ? body.imdbVotes : null,
      };
    }
  }

  for (const entry of body.Ratings || []) {
    const source = entry.Source || '';
    const raw = entry.Value || '';
    if (source === 'Rotten Tomatoes') {
      const value = Number.parseInt(raw.replace('%', ''), 10);
      if (!Number.isNaN(value)) out.rottenTomatoes = { value, scale: 100 };
    } else if (source === 'Metacritic') {
      const value = Number.parseInt(String(raw).split('/')[0], 10);
      if (!Number.isNaN(value)) out.metacritic = { value, scale: 100 };
    } else if (source === 'Internet Movie Database' && !out.imdb) {
      const value = Number.parseFloat(String(raw).split('/')[0]);
      if (!Number.isNaN(value)) out.imdb = { value, scale: 10, votes: null };
    }
  }

  if (!out.metacritic && body.Metascore && body.Metascore !== 'N/A') {
    const value = Number.parseInt(body.Metascore, 10);
    if (!Number.isNaN(value)) out.metacritic = { value, scale: 100 };
  }

  return out;
}

async function fetchTmdbExternal(kind, id, apiKey) {
  const path = kind === 'movie' ? `movie/${id}` : `tv/${id}`;
  const url = new URL(TMDB_BASE + path);
  url.searchParams.set('api_key', apiKey);
  url.searchParams.set('append_to_response', 'external_ids');
  url.searchParams.set('language', 'en-US');
  const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!res.ok) throw new Error(`TMDB ${res.status}`);
  return res.json();
}

function imdbIdFromTmdb(kind, detail) {
  if (kind === 'movie') {
    return detail.imdb_id || detail.external_ids?.imdb_id || null;
  }
  return detail.external_ids?.imdb_id || null;
}

async function fetchOmdb(imdbId, apiKey) {
  const url = new URL(OMDB_BASE);
  url.searchParams.set('apikey', apiKey);
  url.searchParams.set('i', imdbId);
  url.searchParams.set('tomatoes', 'true');
  const res = await fetch(url, { signal: AbortSignal.timeout(8000) });
  if (!res.ok) throw new Error(`OMDb ${res.status}`);
  return res.json();
}

async function buildRatings(kind, id) {
  const tmdbKey = process.env.TMDB_API_KEY;
  const omdbKey = process.env.OMDB_API_KEY;
  if (!tmdbKey) {
    const err = new Error('TMDB is not configured on the server.');
    err.status = 503;
    throw err;
  }

  const detail = await fetchTmdbExternal(kind, id, tmdbKey);
  const tmdbScore =
    typeof detail.vote_average === 'number' && detail.vote_average > 0
      ? {
          value: Math.round(detail.vote_average * 10) / 10,
          scale: 10,
          votes: detail.vote_count ?? null,
        }
      : null;

  let omdb = { imdb: null, rottenTomatoes: null, metacritic: null };
  const imdbId = imdbIdFromTmdb(kind, detail);
  if (omdbKey && imdbId) {
    try {
      const body = await fetchOmdb(imdbId, omdbKey);
      omdb = parseOmdbRatings(body);
      // Also accept tomatoMeter when OMDb fills it.
      if (!omdb.rottenTomatoes && body.tomatoMeter && body.tomatoMeter !== 'N/A') {
        const value = Number.parseInt(String(body.tomatoMeter).replace('%', ''), 10);
        if (!Number.isNaN(value)) omdb.rottenTomatoes = { value, scale: 100 };
      }
    } catch (err) {
      console.warn('OMDb fetch failed', err.message);
    }
  }


  const payload = {
    id: Number(id),
    kind,
    imdbId,
    tmdb: tmdbScore,
    imdb: omdb.imdb,
    rottenTomatoes: omdb.rottenTomatoes,
    metacritic: omdb.metacritic,
  };
  return payload;
}

// Memory, then MongoDB (24 h TTL, survives deploys), then one shared build per title.
const ratingsStore = createRatingsStore({
  build: buildRatings,
  ttlMs: CACHE_TTL_MS,
  persist: {
    get: async (key) => (await RatingsCache.findOne({ key, expiresAt: { $gt: new Date() } }).lean())?.payload || null,
    set: (key, payload) => RatingsCache.updateOne(
      { key },
      { $set: { payload, expiresAt: new Date(Date.now() + CACHE_TTL_MS) } },
      { upsert: true }
    ),
  },
});

router.get('/movie/:id', async (req, res) => {
  try {
    const payload = await ratingsStore.get('movie', String(req.params.id));
    res.json(payload);
  } catch (err) {
    res.status(err.status || 500).json({ success: false, message: err.message || 'Ratings failed.' });
  }
});

router.get('/tv/:id', async (req, res) => {
  try {
    const payload = await ratingsStore.get('tv', String(req.params.id));
    res.json(payload);
  } catch (err) {
    res.status(err.status || 500).json({ success: false, message: err.message || 'Ratings failed.' });
  }
});

module.exports = router;
// For tests.
module.exports.parseOmdbRatings = parseOmdbRatings;
